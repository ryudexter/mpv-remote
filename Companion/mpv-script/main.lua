-- MPV Remote: lets the MPV Player Remote iPhone app control this mpv.
--
-- Install by putting this whole folder in ~/.config/mpv/scripts/. When mpv
-- starts, this starts the companion helper that sits next to it. The helper
-- talks to mpv through its IPC socket and to paired phones over Wi-Fi, and
-- quits when mpv does.
--
-- Options, in ~/.config/mpv/script-opts/mpv-remote.conf:
--   port=7655   the port phones connect to
--   name=       how this computer appears on the phone (default: its name)

local utils = require "mp.utils"

local options = { port = 7655, name = "" }
require("mp.options").read_options(options, "mpv-remote")

-- Reuse the socket if mpv already has one (a launcher may rely on its path);
-- otherwise switch one on just for this mpv.
local socket = mp.get_property("input-ipc-server", "")
if socket == "" then
    socket = "/tmp/mpv-remote-" .. mp.get_property("pid") .. ".sock"
    mp.set_property("input-ipc-server", socket)
end
socket = mp.command_native({ "expand-path", socket })

local args = {
    utils.join_path(mp.get_script_directory(), "mpv-remote"),
    "--socket", socket,
    "--port", tostring(options.port),
    "--exit-with-mpv",
    "--log", utils.join_path(os.getenv("HOME"), "Library/Logs/MPV Remote/companion.log"),
}
if options.name ~= "" then
    table.insert(args, "--name")
    table.insert(args, options.name)
end

local result = mp.command_native({ name = "subprocess", args = args, detach = true, playback_only = false })
if not result or result.status ~= 0 then
    mp.msg.error("could not start the MPV Remote helper: " .. tostring(result and result.error_string))
end
