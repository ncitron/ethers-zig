const std = @import("std");
const getty = @import("getty");
const json = @import("json");
const dotenv = @import("dotenv");

const types = @import("types/main.zig");
const U256 = types.U256;
const U64 = types.U64;
const H256 = types.H256;
const Address = types.Address;
const Block = types.Block;
const Transaction = types.Transaction;

pub const Provider = struct {
    allocator: std.mem.Allocator,
    rpc: []const u8,

    pub fn blockNumber(self: Provider) !U64 {
        const req_body = try buildRpcRequest("eth_blockNumber", .{});
        return try self.sendRpcRequest(req_body, U64);
    }

    pub fn getBalance(self: Provider, addr: Address) !U256 {
        const req_body = try buildRpcRequest("eth_getBalance", .{addr});
        return try self.sendRpcRequest(req_body, U256);
    }

    pub fn chainId(self: Provider) !U64 {
        const req_body = try buildRpcRequest("eth_chainId", .{});
        return try self.sendRpcRequest(req_body, U64);
    }

    pub fn getBlockByNumber(self: Provider, comptime TxType: type, number: U64) !Block(TxType) {
        const full_tx = TxType == Transaction;
        const req_body = try buildRpcRequest("eth_getBlockByNumber", .{ number, full_tx });
        return try self.sendRpcRequest(req_body, Block(TxType));
    }

    pub fn getTransactionByHash(self: Provider, hash: H256) !Transaction {
        const req_body = try buildRpcRequest("eth_getTransactionByHash", .{hash});
        return try self.sendRpcRequest(req_body, Transaction);
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
    const allocator = std.testing.allocator;

    const addr = try Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    const req_body = try buildRpcRequest("eth_getBalance", .{addr});

    const req_json = try json.toSlice(allocator, req_body);
    defer allocator.free(req_json);

    const expected = "{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"eth_getBalance\",\"params\":[\"0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5\"]}";
    try std.testing.expect(std.mem.eql(u8, req_json, expected));
}

test "deserialize rpc response" {
    const allocator = std.testing.allocator;

    const resp = "{\"jsonrpc\":\"2.0\",\"id\":0,\"result\":\"0x4d2\"}";
    const parsed = try json.fromSlice(allocator, RpcResponse(U64), resp);

    try std.testing.expectEqual(parsed.result.value, 1234);
}

test "block number" {
    const allocator = std.testing.allocator;

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const block_number = try provider.blockNumber();
    try std.testing.expect(block_number.value > 17_000_000);
}

test "get balance" {
    const allocator = std.testing.allocator;

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const addr = try Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    const balance = try provider.getBalance(addr);

    try std.testing.expect(balance.value > 0);
}

test "chain id" {
    const allocator = std.testing.allocator;

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const chain_id = try provider.chainId();
    try std.testing.expectEqual(chain_id.value, 1);
}

test "get block by number" {
    const allocator = std.testing.allocator;

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const block = try provider.getBlockByNumber(H256, U64.from(17728594));
    defer block.deinit();

    try std.testing.expectEqual(block.number, U64.from(17728594));
}

test "get block by full tx" {
    const allocator = std.testing.allocator;

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const block = try provider.getBlockByNumber(Transaction, U64.from(17728594));
    defer block.deinit();

    try std.testing.expectEqual(block.number, U64.from(17728594));
}

test "get transaction by hash" {
    const allocator = std.testing.allocator;

    const rpc = try dotenv.getEnvVar(allocator, ".env", "mainnet_rpc");
    defer allocator.free(rpc);

    const provider = Provider{ .allocator = allocator, .rpc = rpc };

    const hash = try H256.fromString("0xb87a0074d06fcb53389401b137a5cc741e50d7eabe18a4248edf2a1910b99719");
    const tx = try provider.getTransactionByHash(hash);
    defer tx.deinit();

    try std.testing.expectEqual(tx.hash.?.value, hash.value);
}
