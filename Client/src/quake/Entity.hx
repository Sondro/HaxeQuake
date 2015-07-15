package quake;

import quake.Mod.MModel;

@:publicFields
class Entity {
    var leafs:Array<Int> = [];
    var model:MModel;
    var angles(default,never) = new Vec();
    var msg_angles = [new Vec(), new Vec()];
    var origin(default,never) = new Vec();
    var msg_origins = [new Vec(), new Vec()];
    var frame = 0;
    var syncbase = 0.0;
    var colormap:Int;
    var num:Int;
    var skinnum = 0;
    var msgtime = 0.0;
    var forcelink:Bool;
    var effects = EntityEffect.no;
    var update_type = 0;
    var visframe = 0;
    var dlightframe = 0;
    var dlightbits = 0;
    var baseline(default,never) = new EntityState();
    function new(n = -1) {
        num = n;
    }
}

@:publicFields
class EntityState {
    var origin(default,never) = new Vec();
    var angles(default,never) = new Vec();
    var modelindex = 0;
    var frame = 0;
    var colormap = 0;
    var skin = 0;
    var effects = EntityEffect.no;
    function new() {}
}

@:enum abstract EntityEffect(Int) to Int {
    var no = 0;
    var brightfield = 1;
    var muzzleflash = 2;
    var brightlight = 4;
    var dimlight = 8;
}
