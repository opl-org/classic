fn is_alpha(ch) {
    return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch == "_";
}

fn is_digit(ch) {
    return ch >= "0" && ch <= "9";
}

fn is_alnum(ch) {
    return is_alpha(ch) || is_digit(ch);
}

fn is_space(ch) {
    return ch == " " || ch == "\t" || ch == "\r" || ch == "\n";
}

fn tok(kind, val, line) {
    let m = map();
    m["k"] = kind;
    m["v"] = val;
    m["l"] = line;
    return m;
}

fn tokenize(src) {
    let chars = chars(src);
    let n = len(chars);
    let i = 0;
    let line = 1;
    let tokens = [];

    while i < n {
        let ch = chars[i];
        if is_space(ch) {
            if ch == "\n" {
                line = line + 1;
            }
            i = i + 1;
        } else if ch == "/" && i + 1 < n && chars[i + 1] == "/" {
            i = i + 2;
            while i < n && chars[i] != "\n" {
                i = i + 1;
            }
        } else if ch == "/" && i + 1 < n && chars[i + 1] == "*" {
            i = i + 2;
            while i + 1 < n && !(chars[i] == "*" && chars[i + 1] == "/") {
                if chars[i] == "\n" {
                    line = line + 1;
                }
                i = i + 1;
            }
            if i + 1 >= n {
                print_err("unterminated block comment at line " + str(line));
                exit(1);
            }
            i = i + 2;
        } else if is_alpha(ch) {
            let s = "";
            while i < n && is_alnum(chars[i]) {
                s = s + chars[i];
                i = i + 1;
            }
            if s == "let" || s == "const" || s == "fn" || s == "return" || s == "if" || s == "else" || s == "while" || s == "for" || s == "in" || s == "break" || s == "continue" || s == "true" || s == "false" || s == "null" || s == "try" || s == "catch" || s == "throw" {
                push(tokens, tok(s, s, line));
            } else {
                push(tokens, tok("id", s, line));
            }
        } else if is_digit(ch) {
            let s = "";
            let is_fl = false;
            while i < n && is_digit(chars[i]) {
                s = s + chars[i];
                i = i + 1;
            }
            if i + 1 < n && chars[i] == "." && is_digit(chars[i + 1]) {
                is_fl = true;
                s = s + ".";
                i = i + 1;
                while i < n && is_digit(chars[i]) {
                    s = s + chars[i];
                    i = i + 1;
                }
            }
            if is_fl {
                push(tokens, tok("float", s, line));
            } else {
                push(tokens, tok("int", s, line));
            }
        } else if ch == "\"" {
            let start_line = line;
            i = i + 1;
            let s = "";
            while i < n && chars[i] != "\"" {
                if chars[i] == "\\" {
                    i = i + 1;
                    if i >= n {
                        print_err("unterminated string at line " + str(start_line));
                        exit(1);
                    }
                    let esc = chars[i];
                    if esc == "n" { s = s + "\n"; }
                    else if esc == "t" { s = s + "\t"; }
                    else if esc == "r" { s = s + "\r"; }
                    else if esc == "\\" { s = s + "\\"; }
                    else if esc == "\"" { s = s + "\""; }
                    else if esc == "0" { s = s + "\0"; }
                    else if esc == "x" {
                        if i + 2 >= n {
                            print_err("invalid \\x escape at line " + str(line));
                            exit(1);
                        }
                        let hex = chars[i + 1] + chars[i + 2];
                        i = i + 2;
                        if hex == "1b" || hex == "1B" {
                            s = s + "\x1b";
                        } else {
                            s = s + "\\x" + hex;
                        }
                    } else {
                        s = s + esc;
                    }
                    i = i + 1;
                } else {
                    if chars[i] == "\n" {
                        line = line + 1;
                    }
                    s = s + chars[i];
                    i = i + 1;
                }
            }
            if i >= n {
                print_err("unterminated string at line " + str(start_line));
                exit(1);
            }
            i = i + 1;
            push(tokens, tok("str", s, line));
        } else {
            let two = "";
            if i + 1 < n {
                two = ch + chars[i + 1];
            }
            if two == "==" || two == "!=" || two == "<=" || two == ">=" || two == "&&" || two == "||" || two == "+=" || two == "-=" || two == "*=" || two == "/=" || two == "%=" {
                push(tokens, tok(two, two, line));
                i = i + 2;
            } else if ch == "+" || ch == "-" || ch == "*" || ch == "/" || ch == "%" || ch == "=" || ch == "<" || ch == ">" || ch == "!" || ch == "(" || ch == ")" || ch == "{" || ch == "}" || ch == "[" || ch == "]" || ch == ";" || ch == "," || ch == ":" || ch == "." {
                push(tokens, tok(ch, ch, line));
                i = i + 1;
            } else {
                print_err("unexpected character '" + ch + "' at line " + str(line));
                exit(1);
            }
        }
    }
    push(tokens, tok("eof", "", line));
    return tokens;
}

fn new_parser(tokens) {
    let p = map();
    p["tokens"] = tokens;
    p["pos"] = 0;
    return p;
}

fn peek(p) {
    let toks = p["tokens"];
    return toks[p["pos"]];
}

fn next_tok(p) {
    let t = peek(p);
    p["pos"] = p["pos"] + 1;
    return t;
}

fn expect(p, kind) {
    let t = next_tok(p);
    if t["k"] != kind {
        print_err("expected '" + kind + "', got '" + t["k"] + "' at line " + str(t["l"]));
        exit(1);
    }
    return t;
}

fn escape_rust_str(s) {
    let chs = chars(s);
    let out = "\"";
    let i = 0;
    let n = len(chs);
    while i < n {
        let c = chs[i];
        if c == "\\" { out = out + "\\\\"; }
        else if c == "\"" { out = out + "\\\""; }
        else if c == "\n" { out = out + "\\n"; }
        else if c == "\r" { out = out + "\\r"; }
        else if c == "\t" { out = out + "\\t"; }
        else if c == "\0" { out = out + "\\0"; }
        else if c == "\x1b" { out = out + "\\x1b"; }
        else { out = out + c; }
        i = i + 1;
    }
    out = out + "\"";
    return out;
}

fn parse_expr(p) {
    return parse_or(p);
}

fn parse_or(p) {
    let left = parse_and(p);
    while peek(p)["k"] == "||" {
        next_tok(p);
        let right = parse_and(p);
        left = "(if cls_truthy(&(" + left + ")) { ClsVal::Bool(true) } else { ClsVal::Bool(cls_truthy(&(" + right + "))) })";
    }
    return left;
}

fn parse_and(p) {
    let left = parse_eq(p);
    while peek(p)["k"] == "&&" {
        next_tok(p);
        let right = parse_eq(p);
        left = "(if !cls_truthy(&(" + left + ")) { ClsVal::Bool(false) } else { ClsVal::Bool(cls_truthy(&(" + right + "))) })";
    }
    return left;
}

fn parse_eq(p) {
    let left = parse_rel(p);
    while peek(p)["k"] == "==" || peek(p)["k"] == "!=" {
        let op = next_tok(p)["k"];
        let right = parse_rel(p);
        if op == "==" {
            left = "cls_eq(" + left + ", " + right + ")";
        } else {
            left = "cls_neq(" + left + ", " + right + ")";
        }
    }
    return left;
}

fn parse_rel(p) {
    let left = parse_add(p);
    while peek(p)["k"] == "<" || peek(p)["k"] == "<=" || peek(p)["k"] == ">" || peek(p)["k"] == ">=" {
        let op = next_tok(p)["k"];
        let right = parse_add(p);
        if op == "<" { left = "cls_lt(" + left + ", " + right + ")"; }
        else if op == "<=" { left = "cls_le(" + left + ", " + right + ")"; }
        else if op == ">" { left = "cls_gt(" + left + ", " + right + ")"; }
        else { left = "cls_ge(" + left + ", " + right + ")"; }
    }
    return left;
}

fn parse_add(p) {
    let left = parse_mul(p);
    while peek(p)["k"] == "+" || peek(p)["k"] == "-" {
        let op = next_tok(p)["k"];
        let right = parse_mul(p);
        if op == "+" {
            left = "cls_add(" + left + ", " + right + ")";
        } else {
            left = "cls_sub(" + left + ", " + right + ")";
        }
    }
    return left;
}

fn parse_mul(p) {
    let left = parse_unary(p);
    while peek(p)["k"] == "*" || peek(p)["k"] == "/" || peek(p)["k"] == "%" {
        let op = next_tok(p)["k"];
        let right = parse_unary(p);
        if op == "*" { left = "cls_mul(" + left + ", " + right + ")"; }
        else if op == "/" { left = "cls_div(" + left + ", " + right + ")"; }
        else { left = "cls_rem(" + left + ", " + right + ")"; }
    }
    return left;
}

fn parse_unary(p) {
    if peek(p)["k"] == "-" {
        next_tok(p);
        let v = parse_unary(p);
        return "cls_neg(" + v + ")";
    }
    if peek(p)["k"] == "!" {
        next_tok(p);
        let v = parse_unary(p);
        return "cls_not(" + v + ")";
    }
    return parse_postfix(p);
}

fn parse_BuiltinOrCall(name, args) {
    let argc = len(args);
    let joined = "";
    let i = 0;
    while i < argc {
        if i > 0 { joined = joined + ", "; }
        joined = joined + args[i];
        i = i + 1;
    }

    if name == "print" || name == "println" || name == "print_err" || name == "print_warn" || name == "len" || name == "push" || name == "pop" || name == "str" || name == "int" || name == "float" || name == "type_of" || name == "chars" || name == "split" || name == "join" || name == "trim" || name == "contains" || name == "starts_with" || name == "ends_with" || name == "substr" || name == "replace" || name == "keys" || name == "has_key" || name == "remove" || name == "map" || name == "read_file" || name == "write_file" || name == "append_file" || name == "file_exists" || name == "remove_file" || name == "args" || name == "exit" || name == "shell" || name == "env_get" || name == "time_ms" || name == "input" || name == "assert" || name == "abs" || name == "min" || name == "max" || name == "sqrt" || name == "pow" || name == "floor" || name == "ceil" || name == "round" || name == "ord" || name == "chr" || name == "exec_rustc" || name == "wrap_with_runtime" {
        return "cls_builtin_" + name + "(vec![" + joined + "])";
    }
    return "cls_fn_" + name + "(" + joined + ")";
}

fn parse_postfix(p) {
    let expr = parse_primary(p);
    while peek(p)["k"] == "[" || peek(p)["k"] == "." {
        if peek(p)["k"] == "[" {
            next_tok(p);
            let idx = parse_expr(p);
            expect(p, "]");
            expr = "cls_index_get(&(" + expr + "), " + idx + ")";
        } else {
            next_tok(p);
            let prop = expect(p, "id")["v"];
            expr = "cls_index_get(&(" + expr + "), ClsVal::Str(Rc::new(" + escape_rust_str(prop) + ".to_string())))";
        }
    }
    return expr;
}

fn parse_primary(p) {
    let t = peek(p);
    let k = t["k"];

    if k == "int" {
        next_tok(p);
        return "ClsVal::Int(" + t["v"] + "i64)";
    }
    if k == "float" {
        next_tok(p);
        return "ClsVal::Float(" + t["v"] + "f64)";
    }
    if k == "true" {
        next_tok(p);
        return "ClsVal::Bool(true)";
    }
    if k == "false" {
        next_tok(p);
        return "ClsVal::Bool(false)";
    }
    if k == "null" {
        next_tok(p);
        return "ClsVal::Null";
    }
    if k == "str" {
        next_tok(p);
        return "ClsVal::Str(Rc::new(" + escape_rust_str(t["v"]) + ".to_string()))";
    }
    if k == "(" {
        next_tok(p);
        let e = parse_expr(p);
        expect(p, ")");
        return "(" + e + ")";
    }
    if k == "[" {
        next_tok(p);
        let items = "";
        let first = true;
        while peek(p)["k"] != "]" {
            if !first { items = items + ", "; }
            first = false;
            items = items + parse_expr(p);
            if peek(p)["k"] == "," {
                next_tok(p);
            } else {
                break;
            }
        }
        expect(p, "]");
        return "ClsVal::Arr(Rc::new(RefCell::new(vec![" + items + "])))";
    }
    if k == "{" {
        next_tok(p);
        let out = "{ let mut _m = BTreeMap::new(); ";
        while peek(p)["k"] != "}" {
            let kt = peek(p);
            let key_str = "";
            if kt["k"] == "str" {
                next_tok(p);
                key_str = escape_rust_str(kt["v"]) + ".to_string()";
            } else if kt["k"] == "id" {
                next_tok(p);
                key_str = escape_rust_str(kt["v"]) + ".to_string()";
            } else {
                let ke = parse_expr(p);
                key_str = "cls_to_string(&(" + ke + "))";
            }
            expect(p, ":");
            let ve = parse_expr(p);
            out = out + "_m.insert(" + key_str + ", " + ve + "); ";
            if peek(p)["k"] == "," {
                next_tok(p);
            } else {
                break;
            }
        }
        expect(p, "}");
        out = out + "ClsVal::Map(Rc::new(RefCell::new(_m))) }";
        return out;
    }
    if k == "id" {
        next_tok(p);
        let name = t["v"];
        if peek(p)["k"] == "(" {
            next_tok(p);
            let args = [];
            while peek(p)["k"] != ")" {
                push(args, parse_expr(p));
                if peek(p)["k"] == "," {
                    next_tok(p);
                } else {
                    break;
                }
            }
            expect(p, ")");
            return parse_BuiltinOrCall(name, args);
        }
        return "cls_var_" + name + ".clone()";
    }

    print_err("unexpected token '" + k + "' ('" + t["v"] + "') at line " + str(t["l"]));
    exit(1);
}

fn parse_block(p) {
    expect(p, "{");
    let out = "{\n";
    while peek(p)["k"] != "}" && peek(p)["k"] != "eof" {
        out = out + parse_stmt(p);
    }
    expect(p, "}");
    out = out + "}\n";
    return out;
}

fn parse_stmt(p) {
    let t = peek(p);
    let k = t["k"];

    if k == "let" || k == "const" {
        next_tok(p);
        let name = expect(p, "id")["v"];
        let val = "ClsVal::Null";
        if peek(p)["k"] == "=" {
            next_tok(p);
            val = parse_expr(p);
        }
        if peek(p)["k"] == ";" { next_tok(p); }
        return "let mut cls_var_" + name + ": ClsVal = " + val + ";\n";
    }

    if k == "return" {
        next_tok(p);
        if peek(p)["k"] == ";" || peek(p)["k"] == "}" {
            if peek(p)["k"] == ";" { next_tok(p); }
            return "return ClsVal::Null;\n";
        }
        let val = parse_expr(p);
        if peek(p)["k"] == ";" { next_tok(p); }
        return "return " + val + ";\n";
    }

    if k == "if" {
        next_tok(p);
        let cond = parse_expr(p);
        let body = parse_block(p);
        let out = "if cls_truthy(&(" + cond + ")) " + body;
        while peek(p)["k"] == "else" {
            next_tok(p);
            if peek(p)["k"] == "if" {
                next_tok(p);
                let c2 = parse_expr(p);
                let b2 = parse_block(p);
                out = out + " else if cls_truthy(&(" + c2 + ")) " + b2;
            } else {
                let b2 = parse_block(p);
                out = out + " else " + b2;
                break;
            }
        }
        return out + "\n";
    }

    if k == "while" {
        next_tok(p);
        let cond = parse_expr(p);
        let body = parse_block(p);
        return "while cls_truthy(&(" + cond + ")) " + body + "\n";
    }

    if k == "for" {
        next_tok(p);
        let varname = expect(p, "id")["v"];
        expect(p, "in");
        let iter_expr = parse_expr(p);
        let body = parse_block(p);
        return "for cls_iter_item in cls_iter_vec(&(" + iter_expr + ")) {\nlet mut cls_var_" + varname + " = cls_iter_item;\n" + body + "}\n";
    }

    if k == "break" {
        next_tok(p);
        if peek(p)["k"] == ";" { next_tok(p); }
        return "break;\n";
    }

    if k == "continue" {
        next_tok(p);
        if peek(p)["k"] == ";" { next_tok(p); }
        return "continue;\n";
    }

    if k == "try" {
        next_tok(p);
        let try_b = parse_block(p);
        expect(p, "catch");
        let err_var = "err";
        if peek(p)["k"] == "(" {
            next_tok(p);
            err_var = expect(p, "id")["v"];
            expect(p, ")");
        } else if peek(p)["k"] == "id" {
            err_var = next_tok(p)["v"];
        }
        let catch_b = parse_block(p);
        return "{\nlet _res = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {\n" + try_b + "ClsVal::Null\n}));\nif let Err(_payload) = _res {\nlet mut cls_var_" + err_var + " = cls_extract_panic(_payload);\n" + catch_b + "}\n}\n";
    }

    if k == "throw" {
        next_tok(p);
        let e = parse_expr(p);
        if peek(p)["k"] == ";" { next_tok(p); }
        return "panic!(\"{}\", cls_to_string(&(" + e + ")));\n";
    }

    if k == "{" {
        return parse_block(p);
    }

    if k == "id" {
        let save = p["pos"];
        let name = next_tok(p)["v"];
        let nk = peek(p)["k"];

        if nk == "=" || nk == "+=" || nk == "-=" || nk == "*=" || nk == "/=" || nk == "%=" {
            let op = next_tok(p)["k"];
            let rhs = parse_expr(p);
            if peek(p)["k"] == ";" { next_tok(p); }
            if op == "=" {
                return "cls_var_" + name + " = " + rhs + ";\n";
            } else if op == "+=" {
                return "cls_var_" + name + " = cls_add(cls_var_" + name + ".clone(), " + rhs + ");\n";
            } else if op == "-=" {
                return "cls_var_" + name + " = cls_sub(cls_var_" + name + ".clone(), " + rhs + ");\n";
            } else if op == "*=" {
                return "cls_var_" + name + " = cls_mul(cls_var_" + name + ".clone(), " + rhs + ");\n";
            } else if op == "/=" {
                return "cls_var_" + name + " = cls_div(cls_var_" + name + ".clone(), " + rhs + ");\n";
            } else {
                return "cls_var_" + name + " = cls_rem(cls_var_" + name + ".clone(), " + rhs + ");\n";
            }
        }

        if nk == "[" || nk == "." {
            let indices = [];
            while peek(p)["k"] == "[" || peek(p)["k"] == "." {
                if peek(p)["k"] == "[" {
                    next_tok(p);
                    push(indices, parse_expr(p));
                    expect(p, "]");
                } else {
                    next_tok(p);
                    let prop = expect(p, "id")["v"];
                    push(indices, "ClsVal::Str(Rc::new(" + escape_rust_str(prop) + ".to_string()))");
                }
            }
            if peek(p)["k"] == "=" {
                next_tok(p);
                let rhs = parse_expr(p);
                if peek(p)["k"] == ";" { next_tok(p); }
                if len(indices) == 1 {
                    return "cls_index_set(&cls_var_" + name + ", " + indices[0] + ", " + rhs + ");\n";
                } else {
                    let target = "cls_var_" + name + ".clone()";
                    let idx_i = 0;
                    while idx_i < len(indices) - 1 {
                        target = "cls_index_get(&(" + target + "), " + indices[idx_i] + ")";
                        idx_i = idx_i + 1;
                    }
                    return "{ let _t = " + target + "; cls_index_set(&_t, " + indices[len(indices) - 1] + ", " + rhs + "); }\n";
                }
            }
        }

        p["pos"] = save;
    }

    let e = parse_expr(p);
    if peek(p)["k"] == ";" { next_tok(p); }
    return e + ";\n";
}

fn compile_ast(tokens) {
    let p = new_parser(tokens);
    let funcs = "";
    let top_stmts = "";
    let has_user_main = false;

    while peek(p)["k"] != "eof" {
        if peek(p)["k"] == "fn" {
            next_tok(p);
            let fname = expect(p, "id")["v"];
            if fname == "main" {
                has_user_main = true;
            }
            expect(p, "(");
            let params = [];
            while peek(p)["k"] != ")" {
                push(params, expect(p, "id")["v"]);
                if peek(p)["k"] == "," {
                    next_tok(p);
                } else {
                    break;
                }
            }
            expect(p, ")");
            let body = parse_block(p);
            let sig = "";
            let mut_binds = "";
            let i = 0;
            while i < len(params) {
                if i > 0 { sig = sig + ", "; }
                sig = sig + "p_" + params[i] + ": ClsVal";
                mut_binds = mut_binds + "let mut cls_var_" + params[i] + " = p_" + params[i] + ";\n";
                i = i + 1;
            }
            funcs = funcs + "#[allow(unused_mut, unused_variables, non_snake_case, unreachable_code)]\nfn cls_fn_" + fname + "(" + sig + ") -> ClsVal {\n" + mut_binds + body + "ClsVal::Null\n}\n\n";
        } else {
            top_stmts = top_stmts + parse_stmt(p);
        }
    }

    let entry = "#[allow(unused_mut, unused_variables, unreachable_code)]\nfn main() {\n" + top_stmts;
    if has_user_main {
        entry = entry + "cls_fn_main();\n";
    }
    entry = entry + "}\n";

    return wrap_with_runtime(funcs + entry);
}

fn derive_output_path(path) {
    let n = len(path);
    if n > 4 && ends_with(path, ".cls") {
        let out = substr(path, 0, n - 4);
        if len(out) == 0 {
            print_err("invalid source file name '" + path + "'");
            exit(1);
        }
        return out;
    }
    print_warn("source file '" + path + "' does not have a .cls extension");
    return path + ".out";
}

fn compile_file(source_path, output_path) {
    if !file_exists(source_path) {
        print_err("cannot read source file '" + source_path + "': No such file or directory");
        exit(1);
    }
    let src = read_file(source_path);
    let tokens = tokenize(src);
    let rust_code = compile_ast(tokens);

    let temp_rs = output_path + "_classic_temp.rs";
    if !write_file(temp_rs, rust_code) {
        print_err("failed to write intermediate file '" + temp_rs + "'");
        exit(1);
    }
    let ok = exec_rustc(temp_rs, output_path);
    remove_file(temp_rs);
    if !ok {
        exit(1);
    }
}

fn main() {
    let argv = args();
    let argc = len(argv);
    if argc == 1 {
        print_err("no source file specified");
        exit(1);
    } else if argc == 2 {
        let src = argv[1];
        let out = derive_output_path(src);
        compile_file(src, out);
    } else if argc == 3 {
        let src = argv[1];
        if !(len(src) > 4 && ends_with(src, ".cls")) {
            print_warn("source file '" + src + "' does not have a .cls extension");
        }
        compile_file(src, argv[2]);
    } else {
        print_err("usage: classic <source> [output]");
        exit(64);
    }
}
