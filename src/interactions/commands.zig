const std = @import("std");

/// Shared slash-command catalog exposed in Telegram's "/" menu.
/// Kept in interactions core so adapters only render/transport it.
pub const TELEGRAM_BOT_COMMANDS_JSON =
    \\{"commands":[
    \\{"command":"start","description":"Start a conversation"},
    \\{"command":"new","description":"Clear history, start fresh"},
    \\{"command":"reset","description":"Alias for /new"},
    \\{"command":"help","description":"Show available commands"},
    \\{"command":"commands","description":"Alias for /help"},
    \\{"command":"status","description":"Show model and stats"},
    \\{"command":"whoami","description":"Show current session id"},
    \\{"command":"model","description":"Switch model"},
    \\{"command":"models","description":"Alias for /model"},
    \\{"command":"think","description":"Set thinking level"},
    \\{"command":"verbose","description":"Set verbose level"},
    \\{"command":"reasoning","description":"Set reasoning output"},
    \\{"command":"exec","description":"Set exec policy"},
    \\{"command":"queue","description":"Set queue policy"},
    \\{"command":"usage","description":"Set usage footer mode"},
    \\{"command":"tts","description":"Set TTS mode"},
    \\{"command":"memory","description":"Memory tools and diagnostics"},
    \\{"command":"doctor","description":"Memory diagnostics quick check"},
    \\{"command":"stop","description":"Stop active background task"},
    \\{"command":"restart","description":"Restart current session"},
    \\{"command":"compact","description":"Compact context now"}
    \\]}
;

test "interaction commands telegram payload includes memory and doctor commands" {
    try std.testing.expect(std.mem.indexOf(u8, TELEGRAM_BOT_COMMANDS_JSON, "\"command\":\"memory\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, TELEGRAM_BOT_COMMANDS_JSON, "\"command\":\"doctor\"") != null);
}

test "interaction commands telegram payload includes model aliases" {
    try std.testing.expect(std.mem.indexOf(u8, TELEGRAM_BOT_COMMANDS_JSON, "\"command\":\"model\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, TELEGRAM_BOT_COMMANDS_JSON, "\"command\":\"models\"") != null);
}
