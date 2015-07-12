package quake;

import haxe.macro.Context;
import haxe.macro.Expr;

class GlobalVarOfsMacro {
    static function build():Array<Field> {
        var fields = Context.getBuildFields();
        for (f in fields) {
            switch (f.kind) {
                case FVar(_, e):
                    var viewField = switch (f.meta) {
                        case [{name: "f"}]: "_globals_float";
                        case [{name: "i"}]: "_globals_int";
                        default: throw new Error("Invalid field meta", f.pos);
                    }
                    var t = TPath({
                        pack: ["quake"],
                        name: "GlobalVarOfs",
                        params: [TPExpr(macro $v{viewField})]
                    });
                    f.access = [APublic, AStatic];

                    switch (e) {
                        case macro null:
                        default:
                            f.access.push(AInline);
                    }

                    f.kind = FVar(t, macro cast $e);
                default:
                    throw new Error("Invalid field", f.pos);
            }
        }
        return fields;
    }
}