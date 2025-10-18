//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const M: u8 = 0x1b;

const Nk = 4; // key length
const Nb = 4; // block size
const Nr = 10; // Number of rounds

const State = [Nb*4]u8;

const S_BOX: [256]u8 = .{
    // 0     1     2     3     4     5     6     7     8     9     a     b     c     d     e     f
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76, // 0
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0, // 1
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15, // 2
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75, // 3
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84, // 4
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf, // 5
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8, // 6
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2, // 7
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73, // 8
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb, // 9
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, // a
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08, // b
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a, // c
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e, // d
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf, // e
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16, // f
};

const INV_S_BOX: [256]u8 = .{
    // 0     1     2     3     4     5     6     7     8     9     a     b     c     d     e     f
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb, // 0
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb, // 1
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e, // 2
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25, // 3
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92, // 4
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84, // 5
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06, // 6
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b, // 7
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73, // 8
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e, // 9
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b, // a
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4, // b
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f, // c
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef, // d
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61, // e
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d, // f
};

inline fn xtime(a: u8) u8 {
    return (a << 1) ^ (((a & 0x80) >> 7) * M);
}

fn nxtime(a: u8, n: comptime_int) u8 {
    if (n == 0) return a;
    var res = a;
    inline for (0..n) |_| {
        res = xtime(res);
    }
    return res;
}

// fn mult(a: u8, b: u8) u8 {
//     var res: u8 = 0;
//     const map = @Vector(8, u8){ 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 };
//     const map_factors = @Vector(8, u8){ 0, 1, 2, 3, 4, 5, 6, 7 };
//     const tmp_b: @Vector(8, u8) = @splat(b);
//     const factors: [8]u8 = @bitCast(@select(u8, (map & tmp_b) > @as(@Vector(8, u8), @splat(0)), map_factors, @as(@Vector(8, u8), @splat(0xFF))));

//     for (factors) |f| {
//         if (f == 0xFF) continue;
//         res ^= nxtime(a, f);
//     }

//     return res;
// }

inline fn inline_mult(a: u8, b: comptime_int) u8 {
    var res: u8 = 0;
    inline for (0..8)  |bit| {
        if ((b & (@as(u8, 1) << bit)) != 0) {
            res ^= nxtime(a, bit);
        }
    }

    return res;
}

// fn mult32(a: u32, b: u32) u32 {
//     const a0 = @as(u8, @intCast((a & 0xFF)));
//     const a1 = @as(u8, @intCast((a & 0xFF00) >> (8 * 1)));
//     const a2 = @as(u8, @intCast((a & 0xFF0000) >> (8 * 2)));
//     const a3 = @as(u8, @intCast((a & 0xFF000000) >> (8 * 3)));
//     const b0 = @as(u8, @intCast((b & 0xFF)));
//     const b1 = @as(u8, @intCast((b & 0xFF00) >> (8 * 1)));
//     const b2 = @as(u8, @intCast((b & 0xFF0000) >> (8 * 2)));
//     const b3 = @as(u8, @intCast((b & 0xFF000000) >> (8 * 3)));

//     const a0b0 = mult(a0, b0);
//     const a3b1 = mult(a3, b1);
//     const a2b2 = mult(a2, b2);
//     const a1b3 = mult(a1, b3);
//     const res0: u32 = @as(u32, @intCast(a0b0 ^ a3b1 ^ a2b2 ^ a1b3));

//     const a1b0 = mult(a1, b0);
//     const a0b1 = mult(a0, b1);
//     const a3b2 = mult(a3, b2);
//     const a2b3 = mult(a2, b3);
//     const res1: u32 = @as(u32, @intCast(a1b0 ^ a0b1 ^ a3b2 ^ a2b3)) << (8 * 1);

//     const a2b0 = mult(a2, b0);
//     const a1b1 = mult(a1, b1);
//     const a0b2 = mult(a0, b2);
//     const a3b3 = mult(a3, b3);
//     const res2: u32 = @as(u32, @intCast(a2b0 ^ a1b1 ^ a0b2 ^ a3b3)) << (8 * 2);

//     const a3b0 = mult(a3, b0);
//     const a2b1 = mult(a2, b1);
//     const a1b2 = mult(a1, b2);
//     const a0b3 = mult(a0, b3);
//     const res3: u32 = @as(u32, @intCast(a3b0 ^ a2b1 ^ a1b2 ^ a0b3)) << (8 * 3);

//     return res0 ^ res1 ^ res2 ^ res3;
// }

inline fn sbox_sub(a:u8) u8 {
    return S_BOX[((a >> 4) * 0x10) + (a & 0xF)];
}
inline fn inv_sbox_sub(a:u8) u8 {
    return INV_S_BOX[((a >> 4) * 0x10) + (a & 0xF)];
}

fn sub_bytes(state: *State) void {
    for (state) |*byte| {
        byte.* = sbox_sub(byte.*) ;
    }
}
fn inv_sub_bytes(state: *State) void {
    for (state) |*byte| {
        byte.* = inv_sbox_sub(byte.*) ;
    }
}
inline fn rc_coord(r:usize,c:usize) usize {
    return r*Nb + c;
} 

fn shift_rows(state: *State) void {
    var buffer : [Nb]u8 = undefined;

    buffer[0] = state[rc_coord(1, 0)];
    state[rc_coord(1, 0)] = state[rc_coord(1, 1)];
    state[rc_coord(1, 1)] = state[rc_coord(1, 2)];
    state[rc_coord(1, 2)] = state[rc_coord(1, 3)];
    state[rc_coord(1, 3)] = buffer[0];

    
    buffer[0] = state[rc_coord(2, 0)];
    buffer[1] = state[rc_coord(2, 1)];
    state[rc_coord(2, 0)] = state[rc_coord(2, 2)];
    state[rc_coord(2, 1)] = state[rc_coord(2, 3)];
    state[rc_coord(2, 2)] = buffer[0];
    state[rc_coord(2, 3)] = buffer[1];

    
    buffer[0] = state[rc_coord(3, 0)];
    buffer[1] = state[rc_coord(3, 1)];
    buffer[2] = state[rc_coord(3, 2)];
    state[rc_coord(3, 0)] = state[rc_coord(3, 3)];
    state[rc_coord(3, 1)] = buffer[0];
    state[rc_coord(3, 2)] = buffer[1];
    state[rc_coord(3, 3)] = buffer[2];
}

fn inv_shift_rows(state: *State) void {
    var buffer : [Nb]u8 = undefined;

    buffer[0] = state[rc_coord(1, 0)];
    buffer[1] = state[rc_coord(1, 1)];
    buffer[2] = state[rc_coord(1, 2)];
    state[rc_coord(1, 0)] = state[rc_coord(1, 3)];
    state[rc_coord(1, 1)] = buffer[0];
    state[rc_coord(1, 2)] = buffer[1];
    state[rc_coord(1, 3)] = buffer[2];

    
    buffer[0] = state[rc_coord(2, 0)];
    buffer[1] = state[rc_coord(2, 1)];
    state[rc_coord(2, 0)] = state[rc_coord(2, 2)];
    state[rc_coord(2, 1)] = state[rc_coord(2, 3)];
    state[rc_coord(2, 2)] = buffer[0];
    state[rc_coord(2, 3)] = buffer[1];

    
    buffer[0] = state[rc_coord(3, 0)];
    buffer[1] = state[rc_coord(3, 1)];
    buffer[2] = state[rc_coord(3, 2)];
    state[rc_coord(3, 0)] = state[rc_coord(3, 1)];
    state[rc_coord(3, 1)] = state[rc_coord(3, 2)];
    state[rc_coord(3, 2)] = state[rc_coord(3, 3)];
    state[rc_coord(3, 3)] = buffer[0];
}

fn mix_column(state: *State) void {
    var buffer : [4]u8 = undefined;
    inline for (0..Nb) |c| {
        buffer[0] = xtime(state[rc_coord(0,c)]) 
            ^ (xtime(state[rc_coord(1, c)]) ^ state[rc_coord(1, c)])
            ^ state[rc_coord(2, c)]
            ^ state[rc_coord(3, c)];

        buffer[1] = state[rc_coord(0,c)]
            ^ xtime(state[rc_coord(1, c)]) 
            ^ (xtime(state[rc_coord(2, c)]) ^ state[rc_coord(2, c)])
            ^ state[rc_coord(3, c)];

        buffer[2] = state[rc_coord(0,c)] 
            ^ state[rc_coord(1, c)]
            ^ xtime(state[rc_coord(2, c)])
            ^ (xtime(state[rc_coord(3, c)]) ^ state[rc_coord(3, c)]) ;

        buffer[3] = (xtime(state[rc_coord(0,c)]) ^ state[rc_coord(0,c)])
            ^ state[rc_coord(1, c)] 
            ^ state[rc_coord(2, c)]
            ^ xtime(state[rc_coord(3, c)]);

        state[rc_coord(0, c)] = buffer[0];
        state[rc_coord(1, c)] = buffer[1];
        state[rc_coord(2, c)] = buffer[2];
        state[rc_coord(3, c)] = buffer[3];
    }
}

fn inv_mix_column(state: *State) void {
    var buffer : [4]u8 = undefined;
    inline for (0..Nb) |c| {
        buffer[0] = inline_mult(state[rc_coord(0,c)], 0x0e) 
            ^ inline_mult(state[rc_coord(1, c)], 0x0b) 
            ^ inline_mult(state[rc_coord(2, c)], 0x0d)
            ^ inline_mult(state[rc_coord(3, c)], 0x09);

        buffer[1] = inline_mult(state[rc_coord(0,c)], 0x09)
            ^ inline_mult(state[rc_coord(1, c)], 0x0e)
            ^ inline_mult(state[rc_coord(2, c)], 0x0b)
            ^ inline_mult(state[rc_coord(3, c)], 0x0d);

        buffer[2] = inline_mult(state[rc_coord(0,c)], 0x0d) 
            ^ inline_mult(state[rc_coord(1, c)], 0x09)
            ^ inline_mult(state[rc_coord(2, c)], 0x0e) 
            ^ inline_mult(state[rc_coord(3, c)], 0x0b) ;

        buffer[3] = inline_mult(state[rc_coord(0,c)], 0x0b)
            ^ inline_mult(state[rc_coord(1, c)], 0x0d) 
            ^ inline_mult(state[rc_coord(2, c)], 0x09)
            ^ inline_mult(state[rc_coord(3, c)], 0x0e) ;

        state[rc_coord(0, c)] = buffer[0];
        state[rc_coord(1, c)] = buffer[1];
        state[rc_coord(2, c)] = buffer[2];
        state[rc_coord(3, c)] = buffer[3];
    }
}

fn add_roundkey(state: *State, round: usize, w: *[Nb * (Nr + 1)]u32) void {
    inline for (0..Nb) |c| {
        const word = w[round * Nb + c];
        const bytes = std.mem.toBytes(word);
        
        state[rc_coord(0, c)] ^= bytes[3];
        state[rc_coord(1, c)] ^= bytes[2];
        state[rc_coord(2, c)] ^= bytes[1];
        state[rc_coord(3, c)] ^= bytes[0];
    }
}

fn sub_word(word:u32) u32 {
    var bytes : [4]u8 = std.mem.toBytes(word);
    inline for (&bytes) |*b| {
        b.* = sbox_sub(b.*);
    }
    return @bitCast((&bytes).*);
}

fn rot_word(word:u32) u32 {
    return (word << (8)) ^ (word >> (8*3));
}

fn key_expansion(key : *const [4*Nk]u8, w: *[Nb*(Nr+1)]u32) void {

    inline for(0..Nk) |i| {
        w[i] = @bitCast((&[4]u8{key[4*i+3],key[4*i+2],key[4*i+1],key[4*i]}).*);
    }
    const rcon : [11]u32 = .{0, 0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000, 0x20000000, 0x40000000, 0x80000000, 0x1B000000, 0x36000000};

    for (Nk..Nb*(Nr+1)) |i| {
        var tmp = w[i-1];
        if ( (i % Nk) == 0) {
            tmp = sub_word(rot_word(tmp)) ^ rcon[i/Nk];
        } else if ( Nk > 6 and (i % Nk) == 4) {
            tmp = sub_word(tmp);
        }
        w[i] = w[i-Nk] ^ tmp;
    }

}

inline fn dbg_state(state: *State) void {
    for (0..4) |r| {
        for (0..4) |c| {
            std.debug.print("{x}|", .{state[rc_coord(r, c)]});
        }
        std.debug.print("\n", .{});
    }
}

inline fn dbg_round_key(round:usize, w: *[Nb*(Nr+1)]u32) void {

    for (0..4) |c| {
        std.debug.print("{x}|\n", .{w[round * Nb + c]});
    }
}

fn aes_block_cipher(in: *const [4*Nb]u8, out: *[4*Nb]u8, w: *[Nb*(Nr+1)]u32) void {
    var state: State = .{0}**(4*Nb);
    
    @memcpy(&state, in);

    // std.debug.print("Input\n", .{});dbg_state(&state);
    add_roundkey(&state, 0, w);
    // std.debug.print("Round key value\n", .{});dbg_round_key(0,w);

    for (1..Nr) |round| {
        // std.debug.print("Start of round round={d}\n", .{round});dbg_state(&state);
        sub_bytes(&state);
        // std.debug.print("After subBytes round={d}\n", .{round});dbg_state(&state);
        shift_rows(&state);
        // std.debug.print("After shiftRows round={d}\n", .{round});dbg_state(&state);
        mix_column(&state);
        // std.debug.print("After MixColumns round={d}\n", .{round});dbg_state(&state);
        add_roundkey(&state, round, w);
        // std.debug.print("Round key value round={d}\n", .{round});dbg_round_key(round,w);
    }

    sub_bytes(&state);
    shift_rows(&state);
    add_roundkey(&state, Nr, w);

    @memcpy(out, &state);
}

fn aes_block_invcipher(in: *const [4*Nb]u8, out: *[4*Nb]u8, w: *[Nb*(Nr+1)]u32) void {
    var state: State = .{0}**(4*Nb);
    
    @memcpy(&state, in);

    add_roundkey(&state, Nr, w);

    var round:usize = Nr - 1;
    while (round >= 1) : (round -= 1) {
        inv_shift_rows(&state);
        inv_sub_bytes(&state);
        add_roundkey(&state, round, w);
        inv_mix_column(&state);
    }

    inv_shift_rows(&state);
    inv_sub_bytes(&state);

    add_roundkey(&state, 0, w);

    @memcpy(out, &state);
}

// test "test_mult" {
//     try std.testing.expectEqual(1,mult32(0x03010102, 0x0b0d090e));
// }

test "test_sbox_sub" {
    try std.testing.expectEqual(0xed,sbox_sub(0x53));
}
test "test_shift_rows" {
    var state = State{
        0x00, 0x01, 0x02, 0x03,
        0x10, 0x11, 0x12, 0x13,
        0x20, 0x21, 0x22, 0x23,
        0x30, 0x31, 0x32, 0x33,
    };
    const expected_state = State{
        0x00, 0x01, 0x02, 0x03,
        0x11, 0x12, 0x13, 0x10,
        0x22, 0x23, 0x20, 0x21,
        0x33, 0x30, 0x31, 0x32,
    };
    shift_rows(&state);
    try std.testing.expectEqual(expected_state, state);
}

fn benchmark_shift_rows(
    comptime func: anytype,
    name: []const u8,
    state: *State,
    iterations: u32,
) !u64 {
    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        func(state);
    
        std.mem.doNotOptimizeAway(state);
    }

    const end = timer.read();
    const elapsed_ns = end - start;

    std.debug.print("{s}: {} iterations in {d:.2} ms (avg: {d:.2} ns per call)\n", .{
        name,
        iterations,
        @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0,
        @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)),
    });
    
    return elapsed_ns;
}

test "bench_shift_rows" {
    const iterations = 1_000_000;
    
    // Initialize test data
    var state: State = [_]u8{0x32, 0x88, 0x31, 0xe0} ** 4;

    _ = try benchmark_shift_rows(shift_rows, "shift_rows", &state, iterations);
}

fn benchmark_mix_column(
    comptime func: anytype,
    name: []const u8,
    state: *State,
    iterations: u32,
) !u64 {
    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        func(state);
    
        std.mem.doNotOptimizeAway(state);
    }

    const end = timer.read();
    const elapsed_ns = end - start;

    std.debug.print("{s}: {} iterations in {d:.2} ms (avg: {d:.2} ns per call)\n", .{
        name,
        iterations,
        @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0,
        @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)),
    });
    
    return elapsed_ns;
}

test "test_mix_column" {
    var state = State{
        0xd4, 0xe0, 0xb8, 0x1e,
        0xbf, 0xb4, 0x41, 0x27,
        0x5d, 0x52, 0x11, 0x98,
        0x30, 0xae, 0xf1, 0xe5,
    };
    mix_column(&state);
    const expected_state = State{
        0x04, 0xe0, 0x48, 0x28,
        0x66, 0xcb, 0xf8, 0x06,
        0x81, 0x19, 0xd3, 0x26,
        0xe5, 0x9a, 0x7a, 0x4c,
    };
    try std.testing.expectEqual(expected_state, state);
}
test "bench_mix_column" {
    const iterations = 1_000_000;
    
    // Initialize test data
    var state: State = [_]u8{0x32, 0x88, 0x31, 0xe0} ** 4;

    _ = try benchmark_mix_column(mix_column, "mix_column", &state, iterations);
}

test "test_add_roundkey" {
    var state = State{
        0x32, 0x88, 0x31, 0xe0,
        0x43, 0x5a, 0x31, 0x37,
        0xf6, 0x30, 0x98, 0x07,
        0xa8, 0x8d, 0xa2, 0x34,
    };
    var w: [Nb*(Nr+1)]u32 = .{
        0x2b7e1516,0x28aed2a6,0xabf71588,0x09cf4f3c,
        0xa0fafe17,0x88542cb1,0x23a33939,0x2a6c7605,0xf2c295f2,
        0x7a96b943,0x5935807a,0x7359f67f,0x3d80477d,0x4716fe3e,
        0x1e237e44,0x6d7a883b,0xef44a541,0xa8525b7f,0xb671253b,
        0xdb0bad00,0xd4d1c6f8,0x7c839d87,0xcaf2b8bc,0x11f915bc,
        0x6d88a37a,0x110b3efd,0xdbf98641,0xca0093fd,0x4e54f70e,
        0x5f5fc9f3,0x84a64fb2,0x4ea6dc4f,0xead27321,0xb58dbad2,
        0x312bf560,0x7f8d292f,0xac7766f3,0x19fadc21,0x28d12941,
        0x575c006e,0xd014f9a8,0xc9ee2589,0xe13f0cc8,0xb6630ca6
    };
    add_roundkey(&state, 0, &w);
    const expected_state = State{
        0x19, 0xa0, 0x9a, 0xe9,
        0x3d, 0xf4, 0xc6, 0xf8,
        0xe3, 0xe2, 0x8d, 0x48,
        0xbe, 0x2b, 0x2a, 0x08,
    };
    try std.testing.expectEqual(expected_state, state);
}

fn benchmark_add_roundkey(
    comptime func: anytype,
    name: []const u8,
    state: *State,
    round: usize,
    w: *[Nb * (Nr + 1)]u32,
    iterations: u32,
) !u64 {
    var timer = try std.time.Timer.start();
    const start = timer.read();

    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        func(state, round, w);
    
        std.mem.doNotOptimizeAway(state);
    }

    const end = timer.read();
    const elapsed_ns = end - start;

    std.debug.print("{s}: {} iterations in {d:.2} ms (avg: {d:.2} ns per call)\n", .{
        name,
        iterations,
        @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0,
        @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)),
    });
    
    return elapsed_ns;
}

test "bench_add_roundkey" {
        
    const iterations = 1_000_000;
    
    // Initialize test data
    var state: State = [_]u8{0x32, 0x88, 0x31, 0xe0} ** 4;
    var w: [Nb * (Nr + 1)]u32 = [_]u32{0x2b7e1516} ** (Nb * (Nr + 1));
    const round = 1;
    
    _ = try benchmark_add_roundkey(add_roundkey, "add_roundkey", &state, round, &w, iterations);
}

test "test_key_expansion" {
    const key : [4*Nk]u8  = .{0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c};

    var w: [Nb*(Nr+1)]u32 = .{0}**(Nb*(Nr+1));
    key_expansion(&key, &w);
    const expected_w: [Nb*(Nr+1)]u32 = .{
        0x2b7e1516,0x28aed2a6,0xabf71588,0x09cf4f3c,
        0xa0fafe17,0x88542cb1,0x23a33939,0x2a6c7605,0xf2c295f2,
        0x7a96b943,0x5935807a,0x7359f67f,0x3d80477d,0x4716fe3e,
        0x1e237e44,0x6d7a883b,0xef44a541,0xa8525b7f,0xb671253b,
        0xdb0bad00,0xd4d1c6f8,0x7c839d87,0xcaf2b8bc,0x11f915bc,
        0x6d88a37a,0x110b3efd,0xdbf98641,0xca0093fd,0x4e54f70e,
        0x5f5fc9f3,0x84a64fb2,0x4ea6dc4f,0xead27321,0xb58dbad2,
        0x312bf560,0x7f8d292f,0xac7766f3,0x19fadc21,0x28d12941,
        0x575c006e,0xd014f9a8,0xc9ee2589,0xe13f0cc8,0xb6630ca6
    };
    try std.testing.expectEqual(expected_w, w);
}

test "aes_encryption" {
    var input = State{
        0x32, 0x88, 0x31, 0xe0,
        0x43, 0x5a, 0x31, 0x37,
        0xf6, 0x30, 0x98, 0x07,
        0xa8, 0x8d, 0xa2, 0x34,
    };
    var output : [4*Nb]u8 = .{0}**(4*Nb);
    const expected_output : [4*Nb]u8 = .{0x39, 0x02, 0xdc, 0x19, 0x25, 0xdc, 0x11, 0x6a, 0x84, 0x09, 0x85, 0x0b, 0x1d, 0xfb, 0x97, 0x32};
    const key : [4*Nk]u8  = .{0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c};

    var w : [Nb*(Nr+1)]u32 = .{0}**(Nb*(Nr+1));
    key_expansion(&key, &w);
    
    aes_block_cipher(&input, &output, &w);
    try std.testing.expectEqual(expected_output, output);
}
test "aes_decryption" {
    var input :[4*Nb]u8 =  .{0x39, 0x02, 0xdc, 0x19, 0x25, 0xdc, 0x11, 0x6a, 0x84, 0x09, 0x85, 0x0b, 0x1d, 0xfb, 0x97, 0x32};
    var output : [4*Nb]u8 = .{0}**(4*Nb);
    const expected_output : [4*Nb]u8 = State{
        0x32, 0x88, 0x31, 0xe0,
        0x43, 0x5a, 0x31, 0x37,
        0xf6, 0x30, 0x98, 0x07,
        0xa8, 0x8d, 0xa2, 0x34,
    };
    const key : [4*Nk]u8  = .{0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c};

    var w : [Nb*(Nr+1)]u32 = .{0}**(Nb*(Nr+1));
    key_expansion(&key, &w);
    
    aes_block_invcipher(&input, &output, &w);
    try std.testing.expectEqual(expected_output, output);
}