const std = @import("std");
const getty = @import("getty");
const json = @import("json");

const types = @import("main.zig");
const U256 = types.U256;
const U64 = types.U64;
const H2048 = types.H2048;
const H256 = types.H256;
const H64 = types.H64;
const Address = types.Address;

pub fn Block(comptime TxType: type) type {
    return struct {
        hash: H256,
        parent_hash: H256,
        number: U64,
        timestamp: U64,
        base_fee_per_gas: U256,
        gas_limit: U256,
        gas_used: U256,
        miner: Address,
        receipts_root: H256,
        state_root: H256,
        transactions_root: H256,
        uncles_root: H256,
        transactions: std.ArrayList(TxType),
        difficulty: U256,
        extra_data: H256,
        mix_hash: H256,
        nonce: H64,
        size: U256,
        total_difficulty: U256,
        logs_bloom: H2048,

        pub fn deinit(self: @This()) void {
            if (TxType == types.Transaction) {
                for (self.transactions.items) |tx| {
                    tx.deinit();
                }
            }

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
}
