const std = @import("std");
const getty = @import("getty");
const json = @import("json");

const types = @import("main.zig");
const U256 = types.U256;
const U64 = types.U64;
const H256 = types.H256;
const Address = types.Address;
const Bytes = types.Bytes;

pub const Transaction = struct {
    from: Address,
    to: ?Address,
    value: U256,
    input: Bytes,
    hash: ?H256,

    nonce: U256,
    block_hash: ?H256,
    block_number: ?U64,
    transaction_index: ?U64,
    chain_id: U64,

    gas: U256,
    gas_price: ?U256,
    max_fee_per_gas: ?U256,
    max_priority_fee_per_gas: ?U256,

    v: U64,
    r: U256,
    s: U256,

    pub fn deinit(self: Transaction) void {
        self.input.deinit();
    }

    pub const @"getty.db" = struct {
        pub const attributes = .{
            .Container = .{ .ignore_unknown_fields = true },
            .to = .{ .default = null },
            .hash = .{ .default = null },
            .block_hash = .{ .default = null, .rename = "blockHash" },
            .block_number = .{ .default = null, .rename = "blockNumber" },
            .chain_id = .{ .rename = "chainId" },
            .transaction_index = .{ .default = null, .rename = "transactionIndex" },
            .gas_price = .{ .default = null, .rename = "gasPrice" },
            .max_fee_per_gas = .{ .default = null, .rename = "maxFeePerGas" },
            .max_priority_fee_per_gas = .{ .default = null, .rename = "maxPriorityFeePerGas" },
        };
    };
};

pub const TransactionRequest = struct {
    from: ?Address = null,
    to: ?Address = null,
    value: ?U256 = null,
    input: ?Bytes = null,
    chain_id: ?U64 = null,

    gas: ?U256 = null,
    gas_price: ?U256 = null,
    max_fee_per_gas: ?U256 = null,
    max_priority_fee_per_gas: ?U256 = null,

    pub const @"getty.sb" = struct {
        pub fn serialize(allocator: ?std.mem.Allocator, value: anytype, serializer: anytype) !@TypeOf(serializer).Ok {
            var m = try serializer.serializeMap(std.meta.fields(@TypeOf(value)).len);
            const map = m.map();

            inline for (std.meta.fields(TransactionRequest)) |field| {
                const field_value = @field(value, field.name);

                const name = try toCamelCase(allocator.?, field.name);
                defer allocator.?.free(name);

                switch (@typeInfo(@TypeOf(field_value))) {
                    .Optional => {
                        if (field_value) |v| {
                            try map.serializeEntry(name, v);
                        }
                    },
                    else => {
                        try map.serializeEntry(name, field_value);
                    },
                }
            }

            return try map.end();
        }
    };
};

fn toCamelCase(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    var split = std.mem.splitAny(u8, value, "_");
    try list.appendSlice(split.next() orelse return list.items);

    while (split.next()) |word| {
        var word_copy = try allocator.dupe(u8, word);
        defer allocator.free(word_copy);

        word_copy[0] = std.ascii.toUpper(word_copy[0]);
        try list.appendSlice(word_copy);
    }

    return try list.toOwnedSlice();
}

test "deserialize transaction" {
    const tx_json =
        \\{
        \\"blockHash": "0xde97ef27d682f1d0c4f6ca2496e63101dee63c54bfa25da57e9282c84e3310ed",
        \\"blockNumber": "0x10ea0f1",
        \\"from": "0x5111a967b4e1a2598ca152d9aee008a2f1dec321",
        \\"gas": "0x16822",
        \\"gasPrice":"0x130f3e6524",
        \\"maxFeePerGas": "0x106d8d272c",
        \\"maxPriorityFeePerGas": "0xc5229dd61",
        \\"hash": "0xdfc60e0f73927acd90380910e4a8b3164c39719ce42ac8f810a4f8e91df18e3d",
        \\"input": "0xa9059cbb0000000000000000000000000ed98203db63ef0089f9c0f8171255bc092da39900000000000000000000000000000000000000000000000000000000034d7fa8",
        \\"nonce": "0x90e",
        \\"to": "0xdac17f958d2ee523a2206206994597c13d831ec7",
        \\"transactionIndex": "0x1",
        \\"value": "0x0",
        \\"type": "0x2",
        \\"accessList": [],
        \\"chainId": "0x1",
        \\"v": "0x1",
        \\"r": "0x42b2d8707ae29063061db4f6ea7352870fde91f1ee434c624e1c62793236bce2",
        \\"s": "0x98f93884c2280e18601a8a7d98dfaf8004ad6669f31a6cc84206e698bda150"
        \\}
    ;

    const tx = try json.fromSlice(std.testing.allocator, Transaction, tx_json);
    defer tx.deinit();

    const hash = try H256.fromString("0xdfc60e0f73927acd90380910e4a8b3164c39719ce42ac8f810a4f8e91df18e3d");
    try std.testing.expectEqual(tx.hash.?.value, hash.value);
}

test "serialize transaction request" {
    const tx: TransactionRequest = .{
        .to = try Address.fromString("0x6B175474E89094C44Da98b954EedeAC495271d0F"),
        .input = try Bytes.fromString(std.testing.allocator, "0x18160ddd"),
        .chain_id = U64.from(1),
    };

    defer tx.input.?.deinit();

    const tx_json = try json.toSlice(std.testing.allocator, tx);
    defer std.testing.allocator.free(tx_json);

    const expected = "{\"to\":\"0x6b175474e89094c44da98b954eedeac495271d0f\",\"input\":\"0x18160ddd\",\"chainId\":\"0x1\"}";
    try std.testing.expect(std.mem.eql(u8, tx_json, expected));
}
