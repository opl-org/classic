struct Token {
    kind,
    val,
    line,
    col
}

struct LexerState {
    src,
    pos,
    line,
    col
}

struct Node {
    tag,
    name,
    op,
    left,
    right,
    cond,
    body,
    else_body,
    init,
    step,
    params,
    args,
    line,
    col
}

struct ParserState {
    tokens,
    pos
}

struct AnalyzerState {
    scopes,
    func_names,
    func_arity,
    loop_depth
}

fn make_node(tag, line, col) {
    return Node(tag, "", "", null, null, null, [], [], null, null, [], [], line, col);
}

fn is_space(c) {
    return c == " " || c == "\n" || c == "\t" || c == "\r";
}

fn is_alpha(c) {
    return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_";
}

fn is_digit(c) {
    return c >= "0" && c <= "9";
}

fn is_alnum(c) {
    return is_alpha(c) || is_digit(c);
}

fn lex_current(st) {
    if st.pos < len(st.src) { return st.src[st.pos]; }
    return "";
}

fn lex_peek(st) {
    if st.pos + 1 < len(st.src) { return st.src[st.pos + 1]; }
    return "";
}

fn lex_advance(st) {
    let c = lex_current(st);
    st.pos += 1;
    if c == "\n" {
        st.line += 1;
        st.col = 1;
    } else {
        st.col += 1;
    }
    return c;
}

fn lex_skip(st) {
    while true {
        while lex_current(st) != "" && is_space(lex_current(st)) {
            lex_advance(st);
        }
        if lex_current(st) == "/" && lex_peek(st) == "/" {
            while lex_current(st) != "" && lex_current(st) != "\n" {
                lex_advance(st);
            }
            continue;
        }
        if lex_current(st) == "/" && lex_peek(st) == "*" {
            let l = st.line;
            let c = st.col;
            lex_advance(st);
            lex_advance(st);
            let closed = false;
            while lex_current(st) != "" {
                if lex_current(st) == "*" && lex_peek(st) == "/" {
                    lex_advance(st);
                    lex_advance(st);
                    closed = true;
                    break;
                }
                lex_advance(st);
            }
            if !closed {
                eprint("Lexer error: [Line " + str(l) + ", Col " + str(c) + "] Unterminated block comment");
                exit(1);
            }
            continue;
        }
        break;
    }
}

fn tokenize(input_str) {
    let st = LexerState(chars(input_str), 0, 1, 1);
    let tokens = [];

    while true {
        lex_skip(st);
        let line = st.line;
        let col = st.col;
        let c = lex_current(st);

        if c == "" {
            push(tokens, Token("Eof", "", line, col));
            break;
        }
        if c == "=" {
            lex_advance(st);
            if lex_current(st) == "=" {
                lex_advance(st);
                push(tokens, Token("Eq", "==", line, col));
            } else {
                push(tokens, Token("Assign", "=", line, col));
            }
            continue;
        }
        if c == "!" {
            lex_advance(st);
            if lex_current(st) == "=" {
                lex_advance(st);
                push(tokens, Token("Ne", "!=", line, col));
            } else {
                push(tokens, Token("Not", "!", line, col));
            }
            continue;
        }
        if c == "<" {
            lex_advance(st);
            if lex_current(st) == "=" {
                lex_advance(st);
                push(tokens, Token("Le", "<=", line, col));
            } else {
                push(tokens, Token("Lt", "<", line, col));
            }
            continue;
        }
        if c == ">" {
            lex_advance(st);
            if lex_current(st) == "=" {
                lex_advance(st);
                push(tokens, Token("Ge", ">=", line, col));
            } else {
                push(tokens, Token("Gt", ">", line, col));
            }
            continue;
        }
        if c == "&" {
            if lex_peek(st) == "&" {
                lex_advance(st);
                lex_advance(st);
                push(tokens, Token("And", "&&", line, col));
                continue;
            }
            eprint("Lexer error: [Line " + str(line) + ", Col " + str(col) + "] Unexpected character '&'");
            exit(1);
        }
        if c == "|" {
            if lex_peek(st) == "|" {
                lex_advance(st);
                lex_advance(st);
                push(tokens, Token("Or", "||", line, col));
                continue;
            }
            eprint("Lexer error: [Line " + str(line) + ", Col " + str(col) + "] Unexpected character '|'");
            exit(1);
        }
        if c == "+" {
            lex_advance(st);
            if lex_current(st) == "=" {
                lex_advance(st);
                push(tokens, Token("PlusAssign", "+=", line, col));
            } else {
                push(tokens, Token("Plus", "+", line, col));
            }
            continue;
        }
        if c == "-" {
            lex_advance(st);
            if lex_current(st) == "=" {
                lex_advance(st);
                push(tokens, Token("MinusAssign", "-=", line, col));
            } else if lex_current(st) == ">" {
                lex_advance(st);
                push(tokens, Token("Arrow", "->", line, col));
            } else {
                push(tokens, Token("Minus", "-", line, col));
            }
            continue;
        }
        if c == "*" {
            lex_advance(st);
            if lex_current(st) == "=" {
                lex_advance(st);
                push(tokens, Token("MulAssign", "*=", line, col));
            } else {
                push(tokens, Token("Asterisk", "*", line, col));
            }
            continue;
        }
        if c == "/" {
            lex_advance(st);
            if lex_current(st) == "=" {
                lex_advance(st);
                push(tokens, Token("DivAssign", "/=", line, col));
            } else {
                push(tokens, Token("Slash", "/", line, col));
            }
            continue;
        }
        if c == "%" { lex_advance(st); push(tokens, Token("Percent", "%", line, col)); continue; }
        if c == "(" { lex_advance(st); push(tokens, Token("LParen", "(", line, col)); continue; }
        if c == ")" { lex_advance(st); push(tokens, Token("RParen", ")", line, col)); continue; }
        if c == "{" { lex_advance(st); push(tokens, Token("LBrace", "{", line, col)); continue; }
        if c == "}" { lex_advance(st); push(tokens, Token("RBrace", "}", line, col)); continue; }
        if c == "[" { lex_advance(st); push(tokens, Token("LBracket", "[", line, col)); continue; }
        if c == "]" { lex_advance(st); push(tokens, Token("RBracket", "]", line, col)); continue; }
        if c == "," { lex_advance(st); push(tokens, Token("Comma", ",", line, col)); continue; }
        if c == ";" { lex_advance(st); push(tokens, Token("Semicolon", ";", line, col)); continue; }
        if c == ":" { lex_advance(st); push(tokens, Token("Colon", ":", line, col)); continue; }
        if c == "." { lex_advance(st); push(tokens, Token("Dot", ".", line, col)); continue; }

        if c == "\"" {
            lex_advance(st);
            let s = "";
            let closed = false;
            while lex_current(st) != "" {
                let ch = lex_current(st);
                if ch == "\"" {
                    lex_advance(st);
                    closed = true;
                    break;
                }
                if ch == "\\" {
                    lex_advance(st);
                    let esc = lex_current(st);
                    if esc == "n" { s = s + "\n"; }
                    else if esc == "t" { s = s + "\t"; }
                    else if esc == "r" { s = s + "\r"; }
                    else if esc == "\"" { s = s + "\""; }
                    else if esc == "\\" { s = s + "\\"; }
                    else {
                        eprint("Lexer error: [Line " + str(st.line) + ", Col " + str(st.col) + "] Invalid escape");
                        exit(1);
                    }
                    lex_advance(st);
                } else {
                    s = s + ch;
                    lex_advance(st);
                }
            }
            if !closed {
                eprint("Lexer error: [Line " + str(line) + ", Col " + str(col) + "] Unterminated string");
                exit(1);
            }
            push(tokens, Token("Str", s, line, col));
            continue;
        }

        if is_alpha(c) {
            let ident = "";
            while lex_current(st) != "" && is_alnum(lex_current(st)) {
                ident = ident + lex_advance(st);
            }
            if ident == "let" { push(tokens, Token("Let", ident, line, col)); }
            else if ident == "fn" { push(tokens, Token("Fn", ident, line, col)); }
            else if ident == "return" { push(tokens, Token("Return", ident, line, col)); }
            else if ident == "if" { push(tokens, Token("If", ident, line, col)); }
            else if ident == "else" { push(tokens, Token("Else", ident, line, col)); }
            else if ident == "while" { push(tokens, Token("While", ident, line, col)); }
            else if ident == "for" { push(tokens, Token("For", ident, line, col)); }
            else if ident == "break" { push(tokens, Token("Break", ident, line, col)); }
            else if ident == "continue" { push(tokens, Token("Continue", ident, line, col)); }
            else if ident == "struct" { push(tokens, Token("Struct", ident, line, col)); }
            else if ident == "true" { push(tokens, Token("True", ident, line, col)); }
            else if ident == "false" { push(tokens, Token("False", ident, line, col)); }
            else if ident == "null" { push(tokens, Token("Null", ident, line, col)); }
            else { push(tokens, Token("Identifier", ident, line, col)); }
            continue;
        }

        if is_digit(c) {
            let num = "";
            let is_fl = false;
            while lex_current(st) != "" {
                let d = lex_current(st);
                if is_digit(d) {
                    num = num + lex_advance(st);
                } else if d == "." && !is_fl && is_digit(lex_peek(st)) {
                    is_fl = true;
                    num = num + lex_advance(st);
                } else {
                    break;
                }
            }
            if is_fl { push(tokens, Token("Float", num, line, col)); }
            else { push(tokens, Token("Int", num, line, col)); }
            continue;
        }

        eprint("Lexer error: [Line " + str(line) + ", Col " + str(col) + "] Illegal character: " + c);
        exit(1);
    }
    return tokens;
}

fn p_cur(p) {
    if p.pos < len(p.tokens) { return p.tokens[p.pos]; }
    return p.tokens[len(p.tokens) - 1];
}

fn p_adv(p) {
    let t = p_cur(p);
    if p.pos + 1 < len(p.tokens) { p.pos += 1; }
    return t;
}

fn p_expect(p, kind) {
    let t = p_cur(p);
    if t.kind == kind { return p_adv(p); }
    eprint("Syntax error: [Line " + str(t.line) + ", Col " + str(t.col) + "] Expected " + kind + ", got " + t.kind);
    exit(1);
}

fn p_expect_ident(p) {
    let t = p_adv(p);
    if t.kind == "Identifier" { return t; }
    eprint("Syntax error: [Line " + str(t.line) + ", Col " + str(t.col) + "] Expected identifier, got " + t.kind);
    exit(1);
}

fn p_skip_opt_type(p) {
    if p_cur(p).kind == "Colon" {
        p_adv(p);
        p_expect_ident(p);
    }
}

fn parse_program(tokens) {
    let p = ParserState(tokens, 0);
    let stmts = [];
    while p_cur(p).kind != "Eof" {
        push(stmts, parse_stmt(p));
    }
    return stmts;
}

fn parse_block(p) {
    p_expect(p, "LBrace");
    let body = [];
    while p_cur(p).kind != "RBrace" && p_cur(p).kind != "Eof" {
        push(body, parse_stmt(p));
    }
    p_expect(p, "RBrace");
    return body;
}

fn parse_stmt(p) {
    let t = p_cur(p);
    let k = t.kind;

    if k == "Let" {
        p_adv(p);
        let id = p_expect_ident(p);
        p_skip_opt_type(p);
        p_expect(p, "Assign");
        let val = parse_expr(p);
        p_expect(p, "Semicolon");
        let n = make_node("StmtLet", t.line, t.col);
        n.name = id.val;
        n.left = val;
        return n;
    }
    if k == "Return" {
        p_adv(p);
        let n = make_node("StmtReturn", t.line, t.col);
        if p_cur(p).kind == "Semicolon" {
            p_adv(p);
            return n;
        }
        n.left = parse_expr(p);
        p_expect(p, "Semicolon");
        return n;
    }
    if k == "Break" {
        p_adv(p);
        p_expect(p, "Semicolon");
        return make_node("StmtBreak", t.line, t.col);
    }
    if k == "Continue" {
        p_adv(p);
        p_expect(p, "Semicolon");
        return make_node("StmtContinue", t.line, t.col);
    }
    if k == "If" {
        p_adv(p);
        let cond = parse_expr(p);
        let then_b = parse_block(p);
        let else_b = [];
        if p_cur(p).kind == "Else" {
            p_adv(p);
            if p_cur(p).kind == "If" { push(else_b, parse_stmt(p)); }
            else { else_b = parse_block(p); }
        }
        let n = make_node("StmtIf", t.line, t.col);
        n.cond = cond;
        n.body = then_b;
        n.else_body = else_b;
        return n;
    }
    if k == "While" {
        p_adv(p);
        let cond = parse_expr(p);
        let body = parse_block(p);
        let n = make_node("StmtWhile", t.line, t.col);
        n.cond = cond;
        n.body = body;
        return n;
    }
    if k == "For" {
        p_adv(p);
        let has_paren = false;
        if p_cur(p).kind == "LParen" {
            p_adv(p);
            has_paren = true;
        }
        let init = null;
        if p_cur(p).kind == "Let" {
            let lt = p_adv(p);
            let id = p_expect_ident(p);
            p_skip_opt_type(p);
            p_expect(p, "Assign");
            let val = parse_expr(p);
            p_expect(p, "Semicolon");
            init = make_node("StmtLet", lt.line, lt.col);
            init.name = id.val;
            init.left = val;
        } else {
            init = parse_assign_or_expr(p, false);
            p_expect(p, "Semicolon");
        }
        let cond = parse_expr(p);
        p_expect(p, "Semicolon");
        let step = parse_assign_or_expr(p, false);
        if has_paren { p_expect(p, "RParen"); }
        let body = parse_block(p);
        let n = make_node("StmtFor", t.line, t.col);
        n.init = init;
        n.cond = cond;
        n.step = step;
        n.body = body;
        return n;
    }
    if k == "Fn" {
        p_adv(p);
        let id = p_expect_ident(p);
        p_expect(p, "LParen");
        let params = [];
        if p_cur(p).kind != "RParen" {
            let pt = p_expect_ident(p);
            p_skip_opt_type(p);
            push(params, pt.val);
            while p_cur(p).kind == "Comma" {
                p_adv(p);
                let pt2 = p_expect_ident(p);
                p_skip_opt_type(p);
                push(params, pt2.val);
            }
        }
        p_expect(p, "RParen");
        if p_cur(p).kind == "Arrow" {
            p_adv(p);
            p_expect_ident(p);
        }
        let body = parse_block(p);
        let n = make_node("StmtFn", t.line, t.col);
        n.name = id.val;
        n.params = params;
        n.body = body;
        return n;
    }
    if k == "Struct" {
        p_adv(p);
        let id = p_expect_ident(p);
        p_expect(p, "LBrace");
        let fields = [];
        while p_cur(p).kind != "RBrace" && p_cur(p).kind != "Eof" {
            let ft = p_expect_ident(p);
            p_skip_opt_type(p);
            push(fields, ft.val);
            if p_cur(p).kind == "Comma" || p_cur(p).kind == "Semicolon" {
                p_adv(p);
            }
        }
        p_expect(p, "RBrace");
        let n = make_node("StmtStruct", t.line, t.col);
        n.name = id.val;
        n.params = fields;
        return n;
    }
    return parse_assign_or_expr(p, true);
}

fn parse_assign_or_expr(p, expect_semi) {
    let t = p_cur(p);
    let expr = parse_expr(p);
    let ck = p_cur(p).kind;
    let cop = "";

    if ck == "Assign" { cop = "="; }
    else if ck == "PlusAssign" { cop = "Add"; }
    else if ck == "MinusAssign" { cop = "Sub"; }
    else if ck == "MulAssign" { cop = "Mul"; }
    else if ck == "DivAssign" { cop = "Div"; }
    else {
        if expect_semi { p_expect(p, "Semicolon"); }
        let en = make_node("StmtExpr", t.line, t.col);
        en.left = expr;
        return en;
    }

    p_adv(p);
    let rhs = parse_expr(p);
    if expect_semi { p_expect(p, "Semicolon"); }

    let val = rhs;
    if cop != "=" {
        val = make_node("ExprBin", t.line, t.col);
        val.op = cop;
        val.left = expr;
        val.right = rhs;
    }
    if expr.tag == "ExprIdent" {
        let an = make_node("StmtAssign", t.line, t.col);
        an.name = expr.name;
        an.left = val;
        return an;
    }
    if expr.tag == "ExprIndex" {
        let idxn = make_node("StmtIndexAssign", t.line, t.col);
        idxn.left = expr.left;
        idxn.right = expr.right;
        idxn.cond = val;
        return idxn;
    }
    if expr.tag == "ExprField" {
        let fn_node = make_node("StmtFieldAssign", t.line, t.col);
        fn_node.left = expr.left;
        fn_node.name = expr.name;
        fn_node.right = val;
        return fn_node;
    }
    eprint("Syntax error: [Line " + str(t.line) + ", Col " + str(t.col) + "] Invalid assignment target");
    exit(1);
}

fn parse_expr(p) { return parse_or(p); }

fn parse_or(p) {
    let left = parse_and(p);
    while p_cur(p).kind == "Or" {
        let t = p_adv(p);
        let right = parse_and(p);
        let n = make_node("ExprBin", t.line, t.col);
        n.op = "Or";
        n.left = left;
        n.right = right;
        left = n;
    }
    return left;
}

fn parse_and(p) {
    let left = parse_comparison(p);
    while p_cur(p).kind == "And" {
        let t = p_adv(p);
        let right = parse_comparison(p);
        let n = make_node("ExprBin", t.line, t.col);
        n.op = "And";
        n.left = left;
        n.right = right;
        left = n;
    }
    return left;
}

fn parse_comparison(p) {
    let left = parse_additive(p);
    while true {
        let k = p_cur(p).kind;
        if k == "Eq" || k == "Ne" || k == "Lt" || k == "Gt" || k == "Le" || k == "Ge" {
            let t = p_adv(p);
            let right = parse_additive(p);
            let n = make_node("ExprBin", t.line, t.col);
            n.op = k;
            n.left = left;
            n.right = right;
            left = n;
        } else {
            break;
        }
    }
    return left;
}

fn parse_additive(p) {
    let left = parse_multiplicative(p);
    while p_cur(p).kind == "Plus" || p_cur(p).kind == "Minus" {
        let t = p_adv(p);
        let right = parse_multiplicative(p);
        let n = make_node("ExprBin", t.line, t.col);
        if t.kind == "Plus" { n.op = "Add"; } else { n.op = "Sub"; }
        n.left = left;
        n.right = right;
        left = n;
    }
    return left;
}

fn parse_multiplicative(p) {
    let left = parse_unary(p);
    while p_cur(p).kind == "Asterisk" || p_cur(p).kind == "Slash" || p_cur(p).kind == "Percent" {
        let t = p_adv(p);
        let right = parse_unary(p);
        let n = make_node("ExprBin", t.line, t.col);
        if t.kind == "Asterisk" { n.op = "Mul"; }
        else if t.kind == "Slash" { n.op = "Div"; }
        else { n.op = "Mod"; }
        n.left = left;
        n.right = right;
        left = n;
    }
    return left;
}

fn parse_unary(p) {
    if p_cur(p).kind == "Minus" {
        let t = p_adv(p);
        let n = make_node("ExprNeg", t.line, t.col);
        n.left = parse_unary(p);
        return n;
    }
    if p_cur(p).kind == "Not" {
        let t = p_adv(p);
        let n = make_node("ExprNot", t.line, t.col);
        n.left = parse_unary(p);
        return n;
    }
    return parse_postfix(p);
}

fn parse_postfix(p) {
    let expr = parse_primary(p);
    while true {
        if p_cur(p).kind == "LBracket" {
            let t = p_adv(p);
            let idx = parse_expr(p);
            p_expect(p, "RBracket");
            let n = make_node("ExprIndex", t.line, t.col);
            n.left = expr;
            n.right = idx;
            expr = n;
        } else if p_cur(p).kind == "Dot" {
            let t = p_adv(p);
            let f = p_expect_ident(p);
            let n = make_node("ExprField", t.line, t.col);
            n.left = expr;
            n.name = f.val;
            expr = n;
        } else {
            break;
        }
    }
    return expr;
}

fn parse_primary(p) {
    let t = p_adv(p);
    let k = t.kind;

    if k == "Int" {
        let n = make_node("ExprInt", t.line, t.col);
        n.name = t.val;
        return n;
    }
    if k == "Float" {
        let n = make_node("ExprFloat", t.line, t.col);
        n.name = t.val;
        return n;
    }
    if k == "True" {
        let n = make_node("ExprBool", t.line, t.col);
        n.name = "true";
        return n;
    }
    if k == "False" {
        let n = make_node("ExprBool", t.line, t.col);
        n.name = "false";
        return n;
    }
    if k == "Str" {
        let n = make_node("ExprStr", t.line, t.col);
        n.name = t.val;
        return n;
    }
    if k == "Null" { return make_node("ExprNull", t.line, t.col); }
    if k == "Identifier" {
        if p_cur(p).kind == "LParen" {
            p_adv(p);
            let call_args = [];
            if p_cur(p).kind != "RParen" {
                push(call_args, parse_expr(p));
                while p_cur(p).kind == "Comma" {
                    p_adv(p);
                    push(call_args, parse_expr(p));
                }
            }
            p_expect(p, "RParen");
            let cn = make_node("ExprCall", t.line, t.col);
            cn.name = t.val;
            cn.args = call_args;
            return cn;
        }
        let idn = make_node("ExprIdent", t.line, t.col);
        idn.name = t.val;
        return idn;
    }
    if k == "LParen" {
        let e = parse_expr(p);
        p_expect(p, "RParen");
        return e;
    }
    if k == "LBracket" {
        let elems = [];
        if p_cur(p).kind != "RBracket" {
            push(elems, parse_expr(p));
            while p_cur(p).kind == "Comma" {
                p_adv(p);
                push(elems, parse_expr(p));
            }
        }
        p_expect(p, "RBracket");
        let an = make_node("ExprArray", t.line, t.col);
        an.args = elems;
        return an;
    }
    eprint("Syntax error: [Line " + str(t.line) + ", Col " + str(t.col) + "] Unexpected token: " + k);
    exit(1);
}

fn sem_register_fn(a, name, arity) {
    for (let i = 0; i < len(a.func_names); i += 1) {
        if a.func_names[i] == name {
            a.func_arity[i] = arity;
            return;
        }
    }
    push(a.func_names, name);
    push(a.func_arity, arity);
}

fn sem_find_fn(a, name) {
    for (let i = 0; i < len(a.func_names); i += 1) {
        if a.func_names[i] == name { return a.func_arity[i]; }
    }
    return -2;
}

fn sem_push_scope(a) { push(a.scopes, []); }
fn sem_pop_scope(a) { pop(a.scopes); }

fn sem_declare(a, name) {
    let top = a.scopes[len(a.scopes) - 1];
    push(top, name);
}

fn sem_is_declared(a, name) {
    let i = len(a.scopes) - 1;
    while i >= 0 {
        let sc = a.scopes[i];
        for (let j = 0; j < len(sc); j += 1) {
            if sc[j] == name { return true; }
        }
        i -= 1;
    }
    return false;
}

fn analyze_program(stmts) {
    let a = AnalyzerState([[]], [], [], 0);
    sem_register_fn(a, "print", -1);
    sem_register_fn(a, "eprint", -1);
    sem_register_fn(a, "input", -1);
    sem_register_fn(a, "len", 1);
    sem_register_fn(a, "array", 1);
    sem_register_fn(a, "push", 2);
    sem_register_fn(a, "pop", 1);
    sem_register_fn(a, "free", 1);
    sem_register_fn(a, "int", 1);
    sem_register_fn(a, "float", 1);
    sem_register_fn(a, "str", 1);
    sem_register_fn(a, "chars", 1);
    sem_register_fn(a, "quote", 1);
    sem_register_fn(a, "read_file", 1);
    sem_register_fn(a, "write_file", 2);
    sem_register_fn(a, "remove_file", 1);
    sem_register_fn(a, "time_ms", 0);
    sem_register_fn(a, "args", 0);
    sem_register_fn(a, "exit", 1);
    sem_register_fn(a, "exec_rustc", 2);
    sem_register_fn(a, "runtime_code", 0);

    for (let i = 0; i < len(stmts); i += 1) {
        let s = stmts[i];
        if s.tag == "StmtFn" || s.tag == "StmtStruct" {
            sem_register_fn(a, s.name, len(s.params));
        }
    }
    for (let i = 0; i < len(stmts); i += 1) {
        sem_check_stmt(a, stmts[i]);
    }
}

fn sem_check_stmt(a, s) {
    let tag = s.tag;
    if tag == "StmtLet" {
        sem_check_expr(a, s.left);
        sem_declare(a, s.name);
        return;
    }
    if tag == "StmtAssign" {
        if !sem_is_declared(a, s.name) {
            eprint("Semantic error: [Line " + str(s.line) + ", Col " + str(s.col) + "] Assignment to undeclared variable '" + s.name + "'");
            exit(1);
        }
        sem_check_expr(a, s.left);
        return;
    }
    if tag == "StmtIndexAssign" {
        sem_check_expr(a, s.left);
        sem_check_expr(a, s.right);
        sem_check_expr(a, s.cond);
        return;
    }
    if tag == "StmtFieldAssign" {
        sem_check_expr(a, s.left);
        sem_check_expr(a, s.right);
        return;
    }
    if tag == "StmtIf" {
        sem_check_expr(a, s.cond);
        sem_push_scope(a);
        for (let i = 0; i < len(s.body); i += 1) { sem_check_stmt(a, s.body[i]); }
        sem_pop_scope(a);
        sem_push_scope(a);
        for (let i = 0; i < len(s.else_body); i += 1) { sem_check_stmt(a, s.else_body[i]); }
        sem_pop_scope(a);
        return;
    }
    if tag == "StmtWhile" {
        sem_check_expr(a, s.cond);
        a.loop_depth += 1;
        sem_push_scope(a);
        for (let i = 0; i < len(s.body); i += 1) { sem_check_stmt(a, s.body[i]); }
        sem_pop_scope(a);
        a.loop_depth -= 1;
        return;
    }
    if tag == "StmtFor" {
        sem_push_scope(a);
        sem_check_stmt(a, s.init);
        sem_check_expr(a, s.cond);
        sem_check_stmt(a, s.step);
        a.loop_depth += 1;
        for (let i = 0; i < len(s.body); i += 1) { sem_check_stmt(a, s.body[i]); }
        a.loop_depth -= 1;
        sem_pop_scope(a);
        return;
    }
    if tag == "StmtBreak" {
        if a.loop_depth == 0 {
            eprint("Semantic error: [Line " + str(s.line) + ", Col " + str(s.col) + "] 'break' used outside of a loop");
            exit(1);
        }
        return;
    }
    if tag == "StmtContinue" {
        if a.loop_depth == 0 {
            eprint("Semantic error: [Line " + str(s.line) + ", Col " + str(s.col) + "] 'continue' used outside of a loop");
            exit(1);
        }
        return;
    }
    if tag == "StmtReturn" {
        if s.left != null { sem_check_expr(a, s.left); }
        return;
    }
    if tag == "StmtExpr" {
        sem_check_expr(a, s.left);
        return;
    }
    if tag == "StmtFn" {
        sem_push_scope(a);
        for (let i = 0; i < len(s.params); i += 1) { sem_declare(a, s.params[i]); }
        for (let i = 0; i < len(s.body); i += 1) { sem_check_stmt(a, s.body[i]); }
        sem_pop_scope(a);
        return;
    }
}

fn sem_check_expr(a, e) {
    let tag = e.tag;
    if tag == "ExprInt" || tag == "ExprFloat" || tag == "ExprBool" || tag == "ExprStr" || tag == "ExprNull" {
        return;
    }
    if tag == "ExprIdent" {
        if !sem_is_declared(a, e.name) {
            eprint("Semantic error: [Line " + str(e.line) + ", Col " + str(e.col) + "] Use of undeclared variable '" + e.name + "'");
            exit(1);
        }
        return;
    }
    if tag == "ExprNeg" || tag == "ExprNot" || tag == "ExprField" {
        sem_check_expr(a, e.left);
        return;
    }
    if tag == "ExprBin" || tag == "ExprIndex" {
        sem_check_expr(a, e.left);
        sem_check_expr(a, e.right);
        return;
    }
    if tag == "ExprArray" {
        for (let i = 0; i < len(e.args); i += 1) { sem_check_expr(a, e.args[i]); }
        return;
    }
    if tag == "ExprCall" {
        for (let i = 0; i < len(e.args); i += 1) { sem_check_expr(a, e.args[i]); }
        let expected = sem_find_fn(a, e.name);
        if expected == -2 {
            eprint("Semantic error: [Line " + str(e.line) + ", Col " + str(e.col) + "] Call to undefined function or struct '" + e.name + "'");
            exit(1);
        }
        if expected >= 0 && expected != len(e.args) {
            eprint("Semantic error: [Line " + str(e.line) + ", Col " + str(e.col) + "] Function '" + e.name + "' expects " + str(expected) + " argument(s), got " + str(len(e.args)));
            exit(1);
        }
        return;
    }
}

fn join_strs(arr, sep) {
    let out = "";
    for (let i = 0; i < len(arr); i += 1) {
        if i > 0 { out = out + sep; }
        out = out + arr[i];
    }
    return out;
}

fn gen_program(stmts) {
    let functions = "";
    let main_body = "";
    let has_user_main = false;

    for (let i = 0; i < len(stmts); i += 1) {
        let s = stmts[i];
        if s.tag == "StmtFn" {
            if s.name == "main" { has_user_main = true; }
            functions = functions + gen_fn(s.name, s.params, s.body);
        } else if s.tag == "StmtStruct" {
            functions = functions + gen_struct_ctor(s.name, s.params);
        } else {
            main_body = main_body + gen_stmt(s);
        }
    }
    if has_user_main { main_body = main_body + "cls_fn_main();\n"; }

    return "#![allow(unused_variables, unused_mut, dead_code, non_snake_case, unreachable_code, unused_parens)]\n"
        + runtime_code() + "\n"
        + functions + "\nfn main() {\n" + main_body + "}\n";
}

fn gen_struct_ctor(name, fields) {
    let params = [];
    let inserts = "";
    for (let i = 0; i < len(fields); i += 1) {
        let f = fields[i];
        push(params, "cls_var_" + f + ": ClsVal");
        inserts = inserts + "map.insert(" + quote(f) + ".to_string(), cls_var_" + f + ");\n";
    }
    return "fn cls_fn_" + name + "(" + join_strs(params, ", ") + ") -> ClsVal {\nlet mut map = BTreeMap::new();\n"
        + inserts + "ClsVal::Struct(Rc::new(RefCell::new(map)))\n}\n";
}

fn gen_fn(name, params, body) {
    let p_list = [];
    for (let i = 0; i < len(params); i += 1) {
        push(p_list, "mut cls_var_" + params[i] + ": ClsVal");
    }
    let b_str = "";
    for (let i = 0; i < len(body); i += 1) {
        b_str = b_str + gen_stmt(body[i]);
    }
    return "fn cls_fn_" + name + "(" + join_strs(p_list, ", ") + ") -> ClsVal {\n" + b_str + "ClsVal::Null\n}\n";
}

fn gen_stmt(s) {
    let tag = s.tag;
    if tag == "StmtLet" { return "let mut cls_var_" + s.name + ": ClsVal = " + gen_expr(s.left) + ";\n"; }
    if tag == "StmtAssign" { return "cls_var_" + s.name + " = " + gen_expr(s.left) + ";\n"; }
    if tag == "StmtIndexAssign" { return "cls_set_index(" + gen_expr(s.left) + ", " + gen_expr(s.right) + ", " + gen_expr(s.cond) + ");\n"; }
    if tag == "StmtFieldAssign" { return "cls_set_field(" + gen_expr(s.left) + ", " + quote(s.name) + ", " + gen_expr(s.right) + ");\n"; }
    if tag == "StmtIf" {
        let t_str = "";
        for (let i = 0; i < len(s.body); i += 1) { t_str = t_str + gen_stmt(s.body[i]); }
        if len(s.else_body) == 0 {
            return "if (" + gen_expr(s.cond) + ").is_truthy() {\n" + t_str + "}\n";
        }
        let e_str = "";
        for (let i = 0; i < len(s.else_body); i += 1) { e_str = e_str + gen_stmt(s.else_body[i]); }
        return "if (" + gen_expr(s.cond) + ").is_truthy() {\n" + t_str + "} else {\n" + e_str + "}\n";
    }
    if tag == "StmtWhile" {
        let b_str = "";
        for (let i = 0; i < len(s.body); i += 1) { b_str = b_str + gen_stmt(s.body[i]); }
        return "while (" + gen_expr(s.cond) + ").is_truthy() {\n" + b_str + "}\n";
    }
    if tag == "StmtFor" {
        let b_str = "";
        for (let i = 0; i < len(s.body); i += 1) { b_str = b_str + gen_stmt(s.body[i]); }
        return "{\n" + gen_stmt(s.init) + "let mut _cls_first = true;\nwhile {\nif !_cls_first {\n"
            + gen_stmt(s.step) + "}\n_cls_first = false;\n(" + gen_expr(s.cond) + ").is_truthy()\n} {\n"
            + b_str + "}\n}\n";
    }
    if tag == "StmtBreak" { return "break;\n"; }
    if tag == "StmtContinue" { return "continue;\n"; }
    if tag == "StmtReturn" {
        if s.left != null { return "return " + gen_expr(s.left) + ";\n"; }
        return "return ClsVal::Null;\n";
    }
    if tag == "StmtExpr" { return gen_expr(s.left) + ";\n"; }
    if tag == "StmtFn" { return gen_fn(s.name, s.params, s.body); }
    if tag == "StmtStruct" { return gen_struct_ctor(s.name, s.params); }
    return "";
}

fn gen_expr(e) {
    let tag = e.tag;
    if tag == "ExprInt" { return "ClsVal::Int(" + e.name + "i64)"; }
    if tag == "ExprFloat" { return "ClsVal::Float(" + e.name + "f64)"; }
    if tag == "ExprBool" { return "ClsVal::Bool(" + e.name + ")"; }
    if tag == "ExprStr" { return "ClsVal::Str(Rc::new(" + quote(e.name) + ".to_string()))"; }
    if tag == "ExprNull" { return "ClsVal::Null"; }
    if tag == "ExprIdent" { return "cls_var_" + e.name + ".clone()"; }
    if tag == "ExprNeg" { return "cls_neg(" + gen_expr(e.left) + ")"; }
    if tag == "ExprNot" { return "ClsVal::Bool(!(" + gen_expr(e.left) + ").is_truthy())"; }
    if tag == "ExprBin" {
        let l = gen_expr(e.left);
        let r = gen_expr(e.right);
        let op = e.op;
        if op == "Add" { return "cls_add(" + l + ", " + r + ")"; }
        if op == "Sub" { return "cls_sub(" + l + ", " + r + ")"; }
        if op == "Mul" { return "cls_mul(" + l + ", " + r + ")"; }
        if op == "Div" { return "cls_div(" + l + ", " + r + ")"; }
        if op == "Mod" { return "cls_mod(" + l + ", " + r + ")"; }
        if op == "Eq" { return "ClsVal::Bool(cls_eq(&(" + l + "), &(" + r + ")))"; }
        if op == "Ne" { return "ClsVal::Bool(!cls_eq(&(" + l + "), &(" + r + ")))"; }
        if op == "Lt" { return "ClsVal::Bool(cls_cmp(&(" + l + "), &(" + r + ")).map(|o| o.is_lt()).unwrap_or(false))"; }
        if op == "Gt" { return "ClsVal::Bool(cls_cmp(&(" + l + "), &(" + r + ")).map(|o| o.is_gt()).unwrap_or(false))"; }
        if op == "Le" { return "ClsVal::Bool(cls_cmp(&(" + l + "), &(" + r + ")).map(|o| o.is_le()).unwrap_or(false))"; }
        if op == "Ge" { return "ClsVal::Bool(cls_cmp(&(" + l + "), &(" + r + ")).map(|o| o.is_ge()).unwrap_or(false))"; }
        if op == "And" {
            return "{ let _l = " + l + "; if !_l.is_truthy() { ClsVal::Bool(false) } else { ClsVal::Bool((" + r + ").is_truthy()) } }";
        }
        if op == "Or" {
            return "{ let _l = " + l + "; if _l.is_truthy() { ClsVal::Bool(true) } else { ClsVal::Bool((" + r + ").is_truthy()) } }";
        }
    }
    if tag == "ExprArray" {
        let el = [];
        for (let i = 0; i < len(e.args); i += 1) { push(el, gen_expr(e.args[i])); }
        return "ClsVal::Array(Rc::new(RefCell::new(vec![" + join_strs(el, ", ") + "])))";
    }
    if tag == "ExprIndex" { return "cls_get_index(" + gen_expr(e.left) + ", " + gen_expr(e.right) + ")"; }
    if tag == "ExprField" { return "cls_get_field(" + gen_expr(e.left) + ", " + quote(e.name) + ")"; }
    if tag == "ExprCall" {
        let a_str = [];
        for (let i = 0; i < len(e.args); i += 1) { push(a_str, gen_expr(e.args[i])); }
        let c = e.name;
        if c == "print" {
            if len(a_str) == 0 { return "{ println!(); ClsVal::Null }"; }
            let pr = [];
            let ph = [];
            for (let i = 0; i < len(a_str); i += 1) {
                push(pr, "cls_to_string(&(" + a_str[i] + "))");
                push(ph, "{}");
            }
            return "{ println!(\"" + join_strs(ph, " ") + "\", " + join_strs(pr, ", ") + "); ClsVal::Null }";
        }
        if c == "eprint" {
            if len(a_str) == 0 { return "{ eprintln!(); ClsVal::Null }"; }
            let pr = [];
            let ph = [];
            for (let i = 0; i < len(a_str); i += 1) {
                push(pr, "cls_to_string(&(" + a_str[i] + "))");
                push(ph, "{}");
            }
            return "{ eprintln!(\"" + join_strs(ph, " ") + "\", " + join_strs(pr, ", ") + "); ClsVal::Null }";
        }
        if c == "input" {
            if len(a_str) > 0 { return "cls_input(Some(" + a_str[0] + "))"; }
            return "cls_input(None)";
        }
        if c == "array" { return "cls_alloc(" + a_str[0] + ")"; }
        if c == "len" { return "cls_len(" + a_str[0] + ")"; }
        if c == "push" { return "cls_push(" + a_str[0] + ", " + a_str[1] + ")"; }
        if c == "pop" { return "cls_pop(" + a_str[0] + ")"; }
        if c == "free" { return "cls_free(" + a_str[0] + ")"; }
        if c == "int" { return "cls_to_int(" + a_str[0] + ")"; }
        if c == "float" { return "cls_to_float(" + a_str[0] + ")"; }
        if c == "str" { return "ClsVal::Str(Rc::new(cls_to_string(&(" + a_str[0] + "))))"; }
        if c == "chars" { return "cls_chars(" + a_str[0] + ")"; }
        if c == "quote" { return "cls_quote(" + a_str[0] + ")"; }
        if c == "read_file" { return "cls_read_file(" + a_str[0] + ")"; }
        if c == "write_file" { return "cls_write_file(" + a_str[0] + ", " + a_str[1] + ")"; }
        if c == "remove_file" { return "cls_remove_file(" + a_str[0] + ")"; }
        if c == "time_ms" { return "cls_time_ms()"; }
        if c == "args" { return "cls_args()"; }
        if c == "exit" { return "cls_exit(" + a_str[0] + ")"; }
        if c == "exec_rustc" { return "cls_exec_rustc(" + a_str[0] + ", " + a_str[1] + ")"; }
        if c == "runtime_code" { return "cls_runtime_code()"; }
        return "cls_fn_" + c + "(" + join_strs(a_str, ", ") + ")";
    }
    return "ClsVal::Null";
}

fn has_cls_ext(path_str) {
    let ch = chars(path_str);
    let n = len(ch);
    if n < 5 { return false; }
    return ch[n - 4] == "." && ch[n - 3] == "c" && ch[n - 2] == "l" && ch[n - 1] == "s";
}

fn strip_cls_ext(path_str) {
    let ch = chars(path_str);
    let out = "";
    for (let i = 0; i < len(ch) - 4; i += 1) { out = out + ch[i]; }
    return out;
}

fn compile_file(source_path, output_path) {
    if !has_cls_ext(source_path) {
        eprint("Error: Source file must have a .cls extension.");
        exit(1);
    }
    let content = read_file(source_path);
    if content == null {
        eprint("Error reading file: " + source_path);
        exit(1);
    }
    let tokens = tokenize(content);
    let ast = parse_program(tokens);
    analyze_program(ast);
    let rust_code = gen_program(ast);

    let temp_rs = output_path + "_classic_temp.rs";
    if !write_file(temp_rs, rust_code) {
        eprint("Failed to write intermediate file: " + temp_rs);
        exit(1);
    }
    let ok = exec_rustc(temp_rs, output_path);
    remove_file(temp_rs);
    if !ok { exit(1); }
}

fn main() {
    let argv = args();
    let argc = len(argv);
    if argc == 1 {
        eprint("No source file specified.");
        exit(1);
    } else if argc == 2 {
        let src = argv[1];
        let out = strip_cls_ext(src);
        compile_file(src, out);
    } else if argc == 3 {
        compile_file(argv[1], argv[2]);
    } else {
        eprint("Usage: classic <Source> [Output]");
        exit(64);
    }
}