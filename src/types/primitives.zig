const std = @import("std");
const getty = @import("getty");
const json = @import("json");

pub const U256 = U(256);
pub const U64 = U(64);

pub const H2048 = H(2048);
pub const H256 = H(256);
pub const H64 = H(64);
pub const Address = H(160);

pub const Bytes = struct {
    value: std.ArrayList(u8),

    pub fn deinit(self: Bytes) void {
        self.value.deinit();
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("0x{}", .{std.fmt.fmtSliceHexLower(self.value.items)});
    }

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

                pub fn visitString(_: @This(), allocator: ?std.mem.Allocator, comptime De: type, string: anytype) De.Error!T {
                    const stripped = if (std.mem.startsWith(u8, string, "0x")) string[2..] else string;

                    const value = try allocator.?.alloc(u8, stripped.len / 2);
                    _ = std.fmt.hexToBytes(value, stripped) catch return De.Error.InvalidValue;
                    return .{ .value = std.ArrayList(u8).fromOwnedSlice(allocator.?, value) };
                }
            };
        }
    };
};

fn U(comptime bits: u16) type {
    const Uint = std.meta.Int(.unsigned, bits);

    return struct {
        value: Uint,

        pub fn from(value: Uint) @This() {
            return .{ .value = value };
        }

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.print("{}", .{self.value});
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

fn H(comptime bits: u16) type {
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

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            const fmt_str = std.fmt.comptimePrint("0x{{x:0>{}}}", .{bits / 8 * 2});
            try writer.print(fmt_str, .{self.value});
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

test "create address" {
    const addr = try Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    try std.testing.expectEqual(addr.value, 1250238713705615060704406741895064647274915793861);
}

test "serialize address" {
    const allocator = std.testing.allocator;

    const addr = try Address.fromString("0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5");
    const addr_json = try json.toSlice(allocator, addr);
    defer allocator.free(addr_json);

    try std.testing.expect(std.mem.eql(u8, addr_json, "\"0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5\""));
}

test "deserialize address" {
    const allocator = std.testing.allocator;

    const addr_json = "\"0xdafea492d9c6733ae3d56b7ed1adb60692c98bc5\"";
    const addr = try json.fromSlice(allocator, Address, addr_json);

    try std.testing.expectEqual(addr.value, 1250238713705615060704406741895064647274915793861);
}

test "create uint" {
    const uint = U(256).from(1234);
    try std.testing.expectEqual(uint.value, 1234);
}

test "serialize uint" {
    const allocator = std.testing.allocator;

    const uint = U(256).from(1234);
    const uint_json = try json.toSlice(allocator, uint);
    defer allocator.free(uint_json);

    try std.testing.expect(std.mem.eql(u8, uint_json, "\"0x4d2\""));
}

test "deserialize uint" {
    const allocator = std.testing.allocator;

    const uint_json = "\"0x4d2\"";
    const uint = try json.fromSlice(allocator, U(256), uint_json);

    try std.testing.expectEqual(uint.value, 1234);
}

test "create hash" {
    const hash = try H(256).fromString("0x4d2");
    try std.testing.expectEqual(hash.value, 1234);
}

test "serialize hash" {
    const allocator = std.testing.allocator;

    const hash = try H(256).fromString("0x1234");
    const hash_json = try json.toSlice(allocator, hash);
    defer allocator.free(hash_json);

    const expected = "\"0x0000000000000000000000000000000000000000000000000000000000001234\"";
    try std.testing.expect(std.mem.eql(u8, hash_json, expected));
}

test "deserialize hash" {
    const allocator = std.testing.allocator;

    const hash_json = "\"0x4d2\"";
    const hash = try json.fromSlice(allocator, H(256), hash_json);

    try std.testing.expectEqual(hash.value, 1234);
}

test "deserialize bytes" {
    const bytes_json = "\"0x1234\"";
    const bytes = try json.fromSlice(std.testing.allocator, Bytes, bytes_json);
    defer bytes.deinit();

    try std.testing.expect(std.mem.eql(u8, bytes.value.items, &[2]u8{ 18, 52 }));
}
