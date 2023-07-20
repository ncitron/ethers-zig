const std = @import("std");
const getty = @import("getty");
const json = @import("json");
const dotenv = @import("dotenv");
const types = @import("types.zig");

pub const Provider = struct {
    allocator: std.mem.Allocator,
    rpc: []const u8,

    pub fn blockNumber(self: Provider) !types.U(64) {
        const req_body = try buildRpcRequest("eth_blockNumber", .{});
        return try self.sendRpcRequest(req_body, types.U(64));
    }

    pub fn getBalance(self: Provider, addr: types.Address) !types.U(256) {
        const req_body = try buildRpcRequest("eth_getBalance", .{addr});
        return try self.sendRpcRequest(req_body, types.U(256));
    }

    pub fn chainId(self: Provider) !types.U(64) {
        const req_body = try buildRpcRequest("eth_chainId", .{});
        return try self.sendRpcRequest(req_body, types.U(64));
    }

    pub fn getBlockByNumber(self: Provider, number: types.U(64)) !types.Block {
        const req_body = try buildRpcRequest("eth_getBlockByNumber", .{ number, false });
        return try self.sendRpcRequest(req_body, types.Block);
    }

    fn sendRpcRequest(self: Provider, rpc_req: anytype, comptime R: type) !R {
        var provider = std.http.Client{ .allocator = self.allocator };
        defer provider.deinit();

        const uri = try std.Uri.parse(self.rpc);

        var headers = std.http.Headers{ .allocator = self.allocator };
        defer headers.deinit();

        try headers.append("accept", "*/*");

        var req = try provider.request(.POST, uri, headers, .{});
        defer req.deinit();

        const req_body = try json.toSlice(self.allocator, rpc_req);
        defer self.allocator.free(req_body);

        req.transfer_encoding = .chunked;
        try req.start();
        try req.writer().writeAll(req_body);

        try req.finish();

        try req.wait();

        const body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(body);

        const resp = try json.fromSlice(self.allocator, RpcResponse(R), body);
        return resp.result;
    }
};

fn RpcResponse(comptime R: type) type {
    return struct {
        id: u32,
        result: R,

        pub const @"getty.db" = struct {
            pub const attributes = .{
                .Container = .{ .ignore_unknown_fields = true },
            };
        };
    };
}

fn RpcRequest(comptime P: type) type {
    return struct {
        jsonrpc: []const u8,
        id: u32,
        method: []const u8,
        params: P,
    };
}

fn buildRpcRequest(method: []const u8, params: anytype) !RpcRequest(@TypeOf(params)) {
    return RpcRequest(@TypeOf(params)){
        .jsonrpc = "2.0",
        .id = 0,
        .method = method,
        .params = params,
    };
}

test "serialize rpc request" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const addr = try types.Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    const req_body = try buildRpcRequest("eth_getBalance", .{addr});

    const req_json = try json.toSlice(allocator, req_body);
    defer allocator.free(req_json);

    const expected = "{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"eth_getBalance\",\"params\":[\"0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5\"]}";
    try std.testing.expect(std.mem.eql(u8, req_json, expected));
}

test "deserialize rpc response" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const resp = "{\"jsonrpc\":\"2.0\",\"id\":0,\"result\":\"0x4d2\"}";
    const parsed = try json.fromSlice(allocator, RpcResponse(types.U(64)), resp);

    try std.testing.expectEqual(parsed.result.value, 1234);
}

test "block number" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const block_number = try provider.blockNumber();
    try std.testing.expect(block_number.value > 17_000_000);
}

test "get balance" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const addr = try types.Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    const balance = try provider.getBalance(addr);

    try std.testing.expect(balance.value > 0);
}

test "chain id" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const chain_id = try provider.chainId();
    try std.testing.expectEqual(chain_id.value, 1);
}

test "get block by number" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const block = try provider.getBlockByNumber(types.U(64).from(17728594));
    defer block.deinit();

    try std.testing.expectEqual(block.number, types.U(64).from(17728594));
}
