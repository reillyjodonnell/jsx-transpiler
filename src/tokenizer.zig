const std = @import("std");
const ArrayList = std.ArrayList;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const test_allocator = std.testing.allocator;
const eql = std.mem.eql;

fn isSame(word1: []const u8, word2: []const u8) bool {
    return eql(u8, word1, word2);
}

fn tokenize(input: []const u8) !ArrayList(Token) {
    const allocator = gpa.allocator();
    var token_list = ArrayList(Token).init(allocator);

    var i: usize = 0;

    var text_buffer = std.ArrayList(u8).init(allocator);
    defer text_buffer.deinit();
    var quoteCount: usize = 0;

    while (i < input.len) : (i += 1) {
        const c = input[i];

        const isPunctuator = isOperator(c);
        // if it's a space, tab, or newline, break
        switch (c) {
            ' ', '\t', '\n' => {
                if (text_buffer.items.len == 1) {
                    if (isOperator(text_buffer.items[0])) {
                        try token_list.append(Token{
                            .type = "Punctuator",
                            .value = text_buffer.items,
                        });
                    }
                }
                // clear the text buffer
                if (text_buffer.items.len > 1) {

                    // deterime if it's a reserved word
                    const isReserved = isReservedWord(text_buffer.items);
                    _ = isReserved;
                    const isString = isStringLiteral(text_buffer.items);

                    if (isString) {
                        try token_list.append(Token{
                            .type = "StringLiteral",
                            .value = text_buffer.items,
                        });
                    }
                    try token_list.append(Token{
                        .type = "IdentifierName",
                        .value = text_buffer.items,
                    });
                }

                // we can't assume we're done with the text buffer as spaces can chain together
                // so we need to check if we're done with the text buffer by seeing if the types dont match
                if (text_buffer.items.len > 1) {
                    const last_character_in_buffer = text_buffer.items[text_buffer.items.len - 1];

                    if (last_character_in_buffer == ' ' or last_character_in_buffer == '\t' or last_character_in_buffer == '\n') {
                        // chain it and keep going
                        try text_buffer.append(c);
                        continue;
                    }
                }

                _ = try text_buffer.toOwnedSlice();
                text_buffer.clearAndFree();
                try text_buffer.append(c);
                try token_list.append(Token{
                    .type = "Whitespace",
                    .value = text_buffer.items,
                });
                _ = try text_buffer.toOwnedSlice();
                text_buffer.clearAndFree();

                continue;
            },
            else => {
                if (c == '"' or c == '\'') {
                    quoteCount += 1;
                    if (quoteCount % 2 != 0) {
                        try text_buffer.append(c);
                    }
                    if (quoteCount % 2 == 0) {
                        try text_buffer.append(c);
                        // we've reached the end of the string
                        try token_list.append(Token{
                            .type = "StringLiteral",
                            .value = text_buffer.items,
                        });
                        _ = try text_buffer.toOwnedSlice();
                        text_buffer.clearAndFree();
                        continue;
                    }
                }
                if (isPunctuator) {
                    // check if there's text in the buffer
                    if (text_buffer.items.len > 0) {
                        try token_list.append(Token{
                            .type = "IdentifierName",
                            .value = text_buffer.items,
                        });
                        _ = try text_buffer.toOwnedSlice();
                        text_buffer.clearAndFree();
                    }
                    _ = try text_buffer.toOwnedSlice();
                    text_buffer.clearAndFree();
                    try text_buffer.append(c);
                    try token_list.append(Token{
                        .type = "Punctuator",
                        .value = text_buffer.items,
                    });
                    _ = try text_buffer.toOwnedSlice();
                    text_buffer.clearAndFree();
                    continue;
                }
                // consume the character and append it to the text buffer
                const isIdStart = isIdStartOrSpecial(c);
                if (isIdStart or c == '_' or c == '$') {
                    try text_buffer.append(c);
                    continue;
                }

                continue;
            },
        }
    }
    return token_list;
}

test "tokenizes basic variable assignment" {
    const input = "const hello = 'world';";
    const tokens = try tokenize(input);
    defer tokens.deinit();

    // iterate through the tokens
    const item = tokens.items;
    try std.testing.expect(std.mem.eql(u8, item[0].type, "IdentifierName"));
    try std.testing.expect(std.mem.eql(u8, item[0].value, "const"));
    try std.testing.expect(std.mem.eql(u8, item[1].type, "Whitespace"));
    try std.testing.expect(std.mem.eql(u8, item[1].value, " "));
    try std.testing.expect(std.mem.eql(u8, item[2].type, "IdentifierName"));
    try std.testing.expect(std.mem.eql(u8, item[2].value, "hello"));
    try std.testing.expect(std.mem.eql(u8, item[3].type, "Whitespace"));
    try std.testing.expect(std.mem.eql(u8, item[3].value, " "));
    try std.testing.expect(std.mem.eql(u8, item[4].type, "Punctuator"));
    try std.testing.expect(std.mem.eql(u8, item[4].value, "="));
    try std.testing.expect(std.mem.eql(u8, item[5].type, "Whitespace"));
    try std.testing.expect(std.mem.eql(u8, item[5].value, " "));
    try std.testing.expect(std.mem.eql(u8, item[6].type, "StringLiteral"));
    try std.testing.expect(std.mem.eql(u8, item[6].value, "'world'"));
    try std.testing.expect(std.mem.eql(u8, item[7].type, "Punctuator"));
    try std.testing.expect(std.mem.eql(u8, item[7].value, ";"));
}

test "tokenizes basic function" {
    // multiline string in zig
    const input =
        \\function test(a, b) {
        \\  return a + b
        \\}
    ;
    const tokens = try tokenize(input);
    defer tokens.deinit();

    const item = tokens.items;
    // try std.testing.expect(std.mem.eql(u8, item[0].type, "IdentifierName"));
    // try std.testing.expect(std.mem.eql(u8, item[0].value, "function"));
    // try std.testing.expect(std.mem.eql(u8, item[1].type, "Whitespace"));
    // try std.testing.expect(std.mem.eql(u8, item[1].value, " "));
    // try std.testing.expect(std.mem.eql(u8, item[2].type, "IdentifierName"));
    // try std.testing.expect(std.mem.eql(u8, item[2].value, "test"));
    // try std.testing.expect(std.mem.eql(u8, item[3].type, "Punctuator"));
    // try std.testing.expect(std.mem.eql(u8, item[3].value, "("));
    // try std.testing.expect(std.mem.eql(u8, item[4].type, "IdentifierName"));
    // try std.testing.expect(std.mem.eql(u8, item[4].value, "a"));
    // try std.testing.expect(std.mem.eql(u8, item[5].type, "Punctuator"));
    // try std.testing.expect(std.mem.eql(u8, item[5].value, ","));
    // try std.testing.expect(std.mem.eql(u8, item[6].type, "Whitespace"));
    // try std.testing.expect(std.mem.eql(u8, item[6].value, " "));
    // try std.testing.expect(std.mem.eql(u8, item[7].type, "IdentifierName"));
    // try std.testing.expect(std.mem.eql(u8, item[7].value, "b"));
    // try std.testing.expect(std.mem.eql(u8, item[8].type, "Punctuator"));
    // try std.testing.expect(std.mem.eql(u8, item[8].value, ")"));
    // try std.testing.expect(std.mem.eql(u8, item[9].type, "Whitespace"));
    // try std.testing.expect(std.mem.eql(u8, item[9].value, " "));
    // try std.testing.expect(std.mem.eql(u8, item[10].type, "Punctuator"));
    // try std.testing.expect(std.mem.eql(u8, item[10].value, "{"));
    // try std.testing.expect(std.mem.eql(u8, item[11].type, "Whitespace"));
    // try std.testing.expect(std.mem.eql(u8, item[11].value, "\n"));
    // try std.testing.expect(std.mem.eql(u8, item[12].type, "Whitespace"));
    // try std.testing.expect(std.mem.eql(u8, item[12].value, "\t"));
    // try std.testing.expect(std.mem.eql(u8, item[13].type, "IdentifierName"));
    // try std.testing.expect(std.mem.eql(u8, item[13].value, "return"));

    for (item) |token| {
        std.debug.print("\n{s} \"{s}\"\n", .{ token.type, token.value });
    }
}

const Token = struct {
    type: []const u8,
    value: []const u8,
};

fn isStringLiteral(word: []const u8) bool {
    // if it's enclosed in quotes it is a string literal
    if (word[0] == '"' and word[word.len - 1] == '"') return true;
    if (word[0] == '\'' and word[word.len - 1] == '\'') return true;
    return false;
}

test "isStringLiteral" {
    const input = "'hello'";
    const isString = isStringLiteral(input);
    try std.testing.expect(isString);
}

// all possible punctuators
// &&  ||  ?? --  ++  .   ?  <   <=   >   >= !=  !==  ==  === +   -   %   &   |   ^   /   *   **   <<   >>   >>> =  +=  -=  %=  &=  |=  ^=  /=  *=  **=  <<=  >>=  >>>=  (  )  [  ]  {  } !  ?  :  ;  ,  ~  ...  =>
fn isOperator(char: u8) bool {
    switch (char) {
        '+' => return true,
        '-' => return true,
        '*' => return true,
        '/' => return true,
        '%' => return true,
        '<' => return true,
        '>' => return true,
        '=' => return true,
        '!' => return true,
        '&' => return true,
        '|' => return true,
        '^' => return true,
        '~' => return true,
        '?' => return true,
        ':' => return true,
        ',' => return true,
        ';' => return true,
        '.' => return true,
        '(' => return true,
        ')' => return true,
        '[' => return true,
        ']' => return true,
        '{' => return true,
        '}' => return true,

        else => return false,
    }

    return false;
}

/// RESERVED WORDS
/// await break case catch class const continue debugger default delete do else enum export extends false finally for function if import in instanceof new null return super switch this throw true try typeof var void while with yield
fn isReservedWord(word: []const u8) bool {
    if (isSame(word, "abstract")) return true;
    if (isSame(word, "arguments")) return true;
    if (isSame(word, "await")) return true;
    if (isSame(word, "boolean")) return true;
    if (isSame(word, "break")) return true;
    if (isSame(word, "byte")) return true;
    if (isSame(word, "case")) return true;
    if (isSame(word, "catch")) return true;
    if (isSame(word, "char")) return true;
    if (isSame(word, "class")) return true;
    if (isSame(word, "const")) return true;
    if (isSame(word, "continue")) return true;
    if (isSame(word, "debugger")) return true;
    if (isSame(word, "default")) return true;
    if (isSame(word, "delete")) return true;
    if (isSame(word, "do")) return true;
    if (isSame(word, "double")) return true;
    if (isSame(word, "else")) return true;
    if (isSame(word, "enum")) return true;
    if (isSame(word, "eval")) return true;
    if (isSame(word, "export")) return true;
    if (isSame(word, "extends")) return true;
    if (isSame(word, "false")) return true;
    if (isSame(word, "final")) return true;
    if (isSame(word, "finally")) return true;
    if (isSame(word, "float")) return true;
    if (isSame(word, "for")) return true;
    if (isSame(word, "function")) return true;
    if (isSame(word, "goto")) return true;
    if (isSame(word, "if")) return true;
    if (isSame(word, "implements")) return true;
    if (isSame(word, "import")) return true;
    if (isSame(word, "in")) return true;
    if (isSame(word, "instanceof")) return true;
    if (isSame(word, "int")) return true;
    if (isSame(word, "interface")) return true;
    if (isSame(word, "let")) return true;
    if (isSame(word, "long")) return true;
    if (isSame(word, "native")) return true;
    if (isSame(word, "new")) return true;
    if (isSame(word, "null")) return true;
    if (isSame(word, "package")) return true;
    if (isSame(word, "private")) return true;
    if (isSame(word, "protected")) return true;
    if (isSame(word, "public")) return true;
    if (isSame(word, "return")) return true;
    if (isSame(word, "short")) return true;
    if (isSame(word, "static")) return true;
    if (isSame(word, "super")) return true;
    if (isSame(word, "switch")) return true;
    if (isSame(word, "synchronized")) return true;
    if (isSame(word, "thisSame")) return true;
    if (isSame(word, "throws")) return true;
    if (isSame(word, "transient")) return true;
    if (isSame(word, "true")) return true;
    if (isSame(word, "try")) return true;
    if (isSame(word, "typeof")) return true;
    if (isSame(word, "var")) return true;
    if (isSame(word, "void")) return true;
    if (isSame(word, "volatile")) return true;
    if (isSame(word, "while")) return true;
    if (isSame(word, "with")) return true;
    if (isSame(word, "yield")) return true;

    return false;
}

fn isIdStartOrSpecial(c: u32) bool {

    // Check Unicode ranges for ID_Start
    return (c >= 0x41 and c <= 0x5A) or // A-Z
        (c >= 0x61 and c <= 0x7A) or // a-z
        (c == 0x24) or // $
        (c == 0x5F) or // _
        (c >= 0xC0 and c <= 0xD6) or // À-Ö
        (c >= 0xD8 and c <= 0xF6) or // Ø-ö
        (c >= 0xF8 and c <= 0x2C1) or // ø-ˁ
        (c >= 0x370 and c <= 0x373) or // Ͱ-ͳ
        (c >= 0x376 and c <= 0x377) or // Ͷ-ͷ
        (c >= 0x37B and c <= 0x37D) or // ͻ-ͽ
        (c >= 0x37F and c <= 0x1FFF) or // Ϳ-῿
        (c >= 0x200C and c <= 0x200D) or // ‌-‍
        (c >= 0x2071 and c <= 0x207F) or // ⁱ-ⁿ
        (c >= 0x2090 and c <= 0x209C) or // ₐ-ₜ
        (c >= 0x2C00 and c <= 0x2DFF) or // Ⰰ-ⷿ
        (c >= 0x2E80 and c <= 0x2FFF) or // ⺀-⿿
        (c >= 0x3004 and c <= 0x3007) or // 〄-〇
        (c >= 0x3021 and c <= 0x302F) or // 〡-〯
        (c >= 0x3031 and c <= 0x3035) or // 〱-〵
        (c >= 0x3038 and c <= 0x303C) or // 〸-〼
        (c >= 0x3041 and c <= 0x3096) or // ぁ-ゖ
        (c >= 0x309D and c <= 0x309F) or // ゝ-ゟ
        (c >= 0x30A1 and c <= 0x30FA) or // ァ-ヺ
        (c >= 0x30FC and c <= 0x30FF) or // ー-ヿ
        (c >= 0x3105 and c <= 0x312F) or // ㄅ-ㄯ
        (c >= 0x3131 and c <= 0x318E) or // ㄱ-ㆎ
        (c >= 0x31A0 and c <= 0x31BF) or // ㆠ-ㆿ
        (c >= 0x3400 and c <= 0x4DBF) or // 㐀-䶿
        (c >= 0x4E00 and c <= 0x9FFF) or // 一-鿿
        (c >= 0xA000 and c <= 0xA48C) or // ꀀ-ꒌ
        (c >= 0xA4D0 and c <= 0xA4FD) or // ꓐ-ꓽ
        (c >= 0xA500 and c <= 0xA60C) or // ꔀ-ꘌ
        (c >= 0xA610 and c <= 0xA61F) or // ꘐ-ꘟ
        (c >= 0xA62A and c <= 0xA62B) or // ꘪ-ꘫ
        (c >= 0xA640 and c <= 0xA66E) or // Ꙁ-ꙮ
        (c >= 0xA67F and c <= 0xA697) or // ꙿ-ꚗ
        (c >= 0xA6A0 and c <= 0xA6EF) or // ꚠ-ꛯ
        (c >= 0xA717 and c <= 0xA71F) or // ꜗ-ꜟ
        (c >= 0xA722 and c <= 0xA788) or // Ꜣ-ꞈ
        (c >= 0xA78B and c <= 0xA7CA) or // Ꞌ-ꟊ
        (c >= 0xA7D0 and c <= 0xA7D1) or // Ꟑ-ꟑ
        (c >= 0xA7D3 and c <= 0xA7D3) or // ꟓ
        (c >= 0xA7D5 and c <= 0xA7D9) or // ꟕ-ꟙ
        (c >= 0xA7F2 and c <= 0xA801) or // ꟲ-ꠁ
        (c >= 0xA803 and c <= 0xA805) or // ꠃ-ꠅ
        (c >= 0xA807 and c <= 0xA80A) or // ꠇ-ꠊ
        (c >= 0xA80C and c <= 0xA822) or // ꠌ-ꠢ
        (c >= 0xA840 and c <= 0xA873) or // ꡀ-ꡳ
        (c >= 0xA882 and c <= 0xA8B3) or // ꢂ-ꢳ
        (c >= 0xA8F2 and c <= 0xA8F7) or // ꣲ-ꣷ
        (c >= 0xA8FB and c <= 0xA8FB) or // ꣻ
        (c >= 0xA8FD and c <= 0xA8FE) or // ꣽ-ꣾ
        (c >= 0xA90A and c <= 0xA925) or // ꤊ-ꤥ
        (c >= 0xA930 and c <= 0xA946) or // ꤰ-ꥆ
        (c >= 0xA960 and c <= 0xA97C) or // ꥠ-ꥼ
        (c >= 0xA984 and c <= 0xA9B2) or // ꦄ-ꦲ
        (c >= 0xA9E0 and c <= 0xA9E4) or // ꧠ-ꧤ
        (c >= 0xA9E6 and c <= 0xA9EF) or // ꧦ-ꧯ
        (c >= 0xA9FA and c <= 0xA9FE) or // ꧺ-ꧾ
        (c >= 0xAA00 and c <= 0xAA28) or // ꨀ-ꨨ
        (c >= 0xAA40 and c <= 0xAA42) or // ꩀ-ꩂ
        (c >= 0xAA44 and c <= 0xAA4B) or // ꩄ-ꩋ
        (c >= 0xAA60 and c <= 0xAA76) or // ꩠ-ꩶ
        (c >= 0xAA7A and c <= 0xAA7A) or // ꩺ
        (c >= 0xAA7E and c <= 0xAAAF) or // ꩾ-ꪯ
        (c >= 0xAAB1 and c <= 0xAAB1) or // ꪱ
        (c >= 0xAAB5 and c <= 0xAAB6) or // ꪵ-ꪶ
        (c >= 0xAAB9 and c <= 0xAABD) or // ꪹ-ꪽ
        (c >= 0xAAC0 and c <= 0xAAC0) or // ꫀ
        (c >= 0xAAC2 and c <= 0xAAC2) or // ꫂ
        (c >= 0xAADB and c <= 0xAADD) or // ꫛ-ꫝ
        (c >= 0xAAE0 and c <= 0xAAEA) or // ꫠ-ꫪ
        (c >= 0xAAF2 and c <= 0xAAF4) or // ꫲ-ꫴ
        (c >= 0xAB01 and c <= 0xAB06) or // ꬁ-ꬆ
        (c >= 0xAB09 and c <= 0xAB0E) or // ꬉ-ꬎ
        (c >= 0xAB11 and c <= 0xAB16) or // ꬑ-ꬖ
        (c >= 0xAB20 and c <= 0xAB26) or // ꬠ-ꬦ
        (c >= 0xAB28 and c <= 0xAB2E) or // ꬨ-ꬮ
        (c >= 0xAB30 and c <= 0xAB5A) or // ꬰ-ꭚ
        (c >= 0xAB5C and c <= 0xAB69) or // ꭜ-ꭩ
        (c >= 0xAB70 and c <= 0xABE2) or // ꭰ-ꯢ
        (c >= 0xAC00 and c <= 0xD7A3) or // 가-힣
        (c >= 0xD7B0 and c <= 0xD7C6) or // ힰ-ퟆ
        (c >= 0xD7CB and c <= 0xD7FB) or // ퟋ-ퟻ
        (c >= 0xF900 and c <= 0xFA6D) or // 豈-舘
        (c >= 0xFA70 and c <= 0xFAD9) or // 並-龎
        (c >= 0xFB00 and c <= 0xFB06) or // ﬀ-ﬆ
        (c >= 0xFB13 and c <= 0xFB17) or // ﬓ-ﬗ
        (c >= 0xFB1D and c <= 0xFB28) or // יִ-ﬨ
        (c >= 0xFB2A and c <= 0xFB36) or // שׁ-זּ
        (c >= 0xFB38 and c <= 0xFB3C) or // טּ-לּ
        (c == 0xFB3E) or // מּ
        (c >= 0xFB40 and c <= 0xFB41) or // ﬀ-ﬁ
        (c >= 0xFB43 and c <= 0xFB44) or // ﬃ-ﬄ
        (c >= 0xFB46 and c <= 0xFBB1) or // ﬆ-בּ
        (c >= 0xFBD3 and c <= 0xFD3D) or // ﭓ-ﴽ
        (c >= 0xFD50 and c <= 0xFD8F) or // ﵐ-ﶏ
        (c >= 0xFD92 and c <= 0xFDC7) or // ﶒ-ﷇ
        (c >= 0xFDF0 and c <= 0xFDFB) or // ﷰ-ﷸ
        (c >= 0xFE70 and c <= 0xFE74) or // ﹰ-ﹴ
        (c >= 0xFE76 and c <= 0xFEFC) or // ﹶ-ﺼ
        (c >= 0xFF21 and c <= 0xFF3A) or // Ａ-Ｚ
        (c >= 0xFF41 and c <= 0xFF5A) or // ａ-ｚ
        (c >= 0xFF66 and c <= 0xFFBE) or // ｦ-ｾ
        (c >= 0xFFC2 and c <= 0xFFC7) or // ￂ-ￇ
        (c >= 0xFFCA and c <= 0xFFCF) or // ￊ-ￏ
        (c >= 0xFFD2 and c <= 0xFFD7) or // ￒ-ￗ
        (c >= 0xFFDA and c <= 0xFFDC); // ￚ-ￜ
}
