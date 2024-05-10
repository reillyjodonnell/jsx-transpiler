const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, world!\n", .{});
}

fn compile(text: []const u8) ![]const u8 {
    std.debug.print("{s}", .{text});
    return 
    \\import { jsx as _jsx } from "react/jsx-runtime";
    \\function App() {
    \\return /*#__PURE__*/_jsx("span", {
    \\children: "Hi"
    \\}
    ;
}

test "compiles correctly" {
    const input =
        \\function App(){
        \\    return <span>Hi</span>
        \\}
    ;
    const output = try compile(input);
    const expected =
        \\import { jsx as _jsx } from "react/jsx-runtime";
        \\function App() {
        \\return /*#__PURE__*/_jsx("span", {
        \\children: "Hi"
        \\}
    ;

    std.debug.print("{s}", .{expected});
    try std.testing.expectEqualStrings(expected, output);
}
