const std = @import("std");
const getty = @import("getty");
const json = @import("json");

pub fn U(comptime bits: u16) type {
    const Uint = std.meta.Int(.unsigned, bits);

    return struct {
        value: Uint,

        pub fn from(value: Uint) @This() {
            return .{ .value = value };
        }

        pub const @"getty.sb" = struct {
            pub fn serialize(allocator: ?std.mem.Allocator, value: anytype, serializer: anytype) !@TypeOf(serializer).Ok {
                const uint_str = try std.fmt.allocPrint(allocator.?, "0x{x}", .{value.value});
                defer allocator.?.free(uint_str);
                return try serializer.serializeString(uint_str);
            }
        };

        pub const @"getty.db" = struct {
            pub fn deserialize(allocator: ?std.mem.Allocator, comptime T: type, deserializer: anytype, value: anytype) !T {
                return deserializer.deserializeAny(allocator, value);
            }

            pub fn Visitor(comptime T: type) type {
                return struct {
                    pub usingnamespace getty.de.Visitor(
                        @This(),
                        T,
                        .{ .visitString = visitString },
                    );

                    pub fn visitString(_: @This(), _: ?std.mem.Allocator, comptime De: type, string: anytype) De.Error!T {
                        const value = try std.fmt.parseInt(Uint, string, 0);
                        return .{ .value = value };
                    }
                };
            }
        };
    };
}

pub fn H(comptime bits: u16) type {
    const Uint = std.meta.Int(.unsigned, bits);

    return struct {
        value: Uint,

        pub fn from(value: Uint) @This() {
            return .{ .value = value };
        }

        pub fn fromString(hash_str: []const u8) !@This() {
            const value = try std.fmt.parseInt(Uint, hash_str, 0);
            return .{ .value = value };
        }

        pub const @"getty.sb" = struct {
            pub fn serialize(allocator: ?std.mem.Allocator, value: anytype, serializer: anytype) !@TypeOf(serializer).Ok {
                const fmt_str = std.fmt.comptimePrint("0x{{x:0>{}}}", .{bits / 8 * 2});
                const hash_str = try std.fmt.allocPrint(allocator.?, fmt_str, .{value.value});
                defer allocator.?.free(hash_str);
                return try serializer.serializeString(hash_str);
            }
        };

        pub const @"getty.db" = struct {
            pub fn deserialize(allocator: ?std.mem.Allocator, comptime T: type, deserializer: anytype, value: anytype) !T {
                return deserializer.deserializeAny(allocator, value);
            }

            pub fn Visitor(comptime T: type) type {
                return struct {
                    pub usingnamespace getty.de.Visitor(
                        @This(),
                        T,
                        .{ .visitString = visitString },
                    );

                    pub fn visitString(_: @This(), _: ?std.mem.Allocator, comptime De: type, string: anytype) De.Error!T {
                        const value = try std.fmt.parseInt(Uint, string, 0);
                        return .{ .value = value };
                    }
                };
            }
        };
    };
}

pub const Address = struct {
    value: u160,

    pub fn fromString(addr_string: []const u8) !Address {
        const value = try std.fmt.parseInt(u160, addr_string, 0);
        return .{ .value = value };
    }

    pub fn toString(self: Address, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "0x{x}", .{self.value});
    }

    pub const @"getty.sb" = struct {
        pub fn serialize(allocator: ?std.mem.Allocator, value: anytype, serializer: anytype) !@TypeOf(serializer).Ok {
            const addr_str = try value.toString(allocator.?);
            defer allocator.?.free(addr_str);
            return try serializer.serializeString(addr_str);
        }
    };

    pub const @"getty.db" = struct {
        pub fn deserialize(allocator: ?std.mem.Allocator, comptime _: type, deserializer: anytype, value: anytype) !Address {
            return deserializer.deserializeAny(allocator, value);
        }

        pub fn Visitor(comptime _: type) type {
            return struct {
                pub usingnamespace getty.de.Visitor(
                    @This(),
                    Address,
                    .{ .visitString = visitString },
                );

                pub fn visitString(_: @This(), _: ?std.mem.Allocator, comptime De: type, string: anytype) De.Error!Address {
                    return try Address.fromString(string);
                }
            };
        }
    };
};

pub const Block = struct {
    hash: H(256),
    parent_hash: H(256),
    number: U(64),
    timestamp: U(64),
    base_fee_per_gas: U(256),
    gas_limit: U(256),
    gas_used: U(256),
    miner: Address,
    receipts_root: H(256),
    state_root: H(256),
    transactions_root: H(256),
    uncles_root: H(256),
    transactions: std.ArrayList(H(256)),
    difficulty: U(256),
    extra_data: H(256),
    mix_hash: H(256),
    nonce: H(64),
    size: U(256),
    total_difficulty: U(256),
    logs_bloom: U(2048),

    pub fn deinit(self: Block) void {
        self.transactions.deinit();
    }

    pub const @"getty.db" = struct {
        pub const attributes = .{
            .Container = .{ .ignore_unknown_fields = true },
            .parent_hash = .{ .rename = "parentHash" },
            .base_fee_per_gas = .{ .rename = "baseFeePerGas" },
            .gas_limit = .{ .rename = "gasLimit" },
            .gas_used = .{ .rename = "gasUsed" },
            .receipts_root = .{ .rename = "receiptsRoot" },
            .state_root = .{ .rename = "stateRoot" },
            .transactions_root = .{ .rename = "transactionsRoot" },
            .uncles_root = .{ .rename = "sha3Uncles" },
            .extra_data = .{ .rename = "extraData" },
            .mix_hash = .{ .rename = "mixHash" },
            .total_difficulty = .{ .rename = "totalDifficulty" },
            .logs_bloom = .{ .rename = "logsBloom" },
        };
    };
};

test "create address" {
    const addr = try Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    try std.testing.expectEqual(addr.value, 1250238713705615060704406741895064647274915793861);
}

test "address to string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const addr = try Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    const addr_string = try addr.toString(allocator);
    defer allocator.free(addr_string);

    try std.testing.expect(std.mem.eql(u8, addr_string, "0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5"));
}

test "serialize address" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const addr = try Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    const addr_json = try json.toSlice(allocator, addr);
    defer allocator.free(addr_json);

    try std.testing.expect(std.mem.eql(u8, addr_json, "\"0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5\""));
}

test "deserialize address" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const addr_json = "\"0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5\"";
    const addr = try json.fromSlice(allocator, Address, addr_json);

    try std.testing.expectEqual(addr.value, 1250238713705615060704406741895064647274915793861);
}

test "create uint" {
    const uint = U(256).from(1234);
    try std.testing.expectEqual(uint.value, 1234);
}

test "serialize uint" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const uint = U(256).from(1234);
    const uint_json = try json.toSlice(allocator, uint);
    defer allocator.free(uint_json);

    try std.testing.expect(std.mem.eql(u8, uint_json, "\"0x4d2\""));
}

test "deserialize uint" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const uint_json = "\"0x4d2\"";
    const uint = try json.fromSlice(allocator, U(256), uint_json);

    try std.testing.expectEqual(uint.value, 1234);
}

test "create hash" {
    const hash = try H(256).fromString("0x4d2");
    try std.testing.expectEqual(hash.value, 1234);
}

test "serialize hash" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const hash = try H(256).fromString("0x1234");
    const hash_json = try json.toSlice(allocator, hash);
    defer allocator.free(hash_json);

    const expected = "\"0x0000000000000000000000000000000000000000000000000000000000001234\"";
    try std.testing.expect(std.mem.eql(u8, hash_json, expected));
}

test "deserialize hash" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("memory leak detected");
    const allocator = gpa.allocator();

    const hash_json = "\"0x4d2\"";
    const hash = try json.fromSlice(allocator, H(256), hash_json);

    try std.testing.expectEqual(hash.value, 1234);
}
