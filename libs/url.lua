local string = require("string")
local base = _G
local table = require("table")
local Url={}
Url._VERSION = "URL 1.0.2"
function Url.escape(s)
return string.gsub(s, "([^A-Za-z0-9_])", function(c)
return string.format("%%%02x", string.byte(c))
end)
end
local function make_set(t)
local s = {}
for i,v in base.ipairs(t) do
s[t[i]] = 1
end
return s
end
local segment_set = make_set {
"-", "_", ".", "!", "~", "*", "'", "(",")", ":", "@", "&", "=", "+", "$", ",",
}
local function protect_segment(s)
return string.gsub(s, "([^A-Za-z0-9_])", function (c)
if segment_set[c] then return c
else return string.format("%%%02x", string.byte(c)) end
end)
end
function Url.unescape(s)
return string.gsub(s, "%%(%x%x)", function(hex)
return string.char(base.tonumber(hex, 16))
end)
end
local function hasolute_path(base_path, relative_path)
if string.sub(relative_path, 1, 1) == "/" then return relative_path end
local path = string.gsub(base_path, "[^/]*$", "")
path = path .. relative_path
path = string.gsub(path, "([^/]*%./)", function (s)
if s ~= "./" then return s else return "" end
end)
path = string.gsub(path, "/%.$", "/")
local reduced
while reduced ~= path do
reduced = path
path = string.gsub(reduced, "([^/]*/%.%./)", function (s)
if s ~= "../../" then return "" else return s end
end)
end
path = string.gsub(reduced, "([^/]*/%.%.)$", function (s)
if s ~= "../.." then return "" else return s end
end)
return path
end
function Url.parse(url, default)
local parsed = {}
for i,v in base.pairs(default or parsed) do parsed[i] = v end
if not url or url == "" then return nil, "invalid url" end
url = string.gsub(url, "#(.*)$", function(f)
parsed.fragment = f
return ""
end)
url = string.gsub(url, "^([%w][%w%+%-%.]*)%:",
function(s) parsed.scheme = s; return "" end)
url = string.gsub(url, "^//([^/]*)", function(n)
parsed.authority = n
return ""
end)
url = string.gsub(url, "%?(.*)", function(q)
parsed.query = q
return ""
end)
url = string.gsub(url, "%;(.*)", function(p)
parsed.params = p
return ""
end)
if url ~= "" then parsed.path = url end
local authority = parsed.authority
if not authority then return parsed end
authority = string.gsub(authority,"^([^@]*)@",
function(u) parsed.userinfo = u; return "" end)
authority = string.gsub(authority, ":([^:]*)$",
function(p) parsed.port = p; return "" end)
if authority ~= "" then parsed.host = authority end
local userinfo = parsed.userinfo
if not userinfo then return parsed end
userinfo = string.gsub(userinfo, ":([^:]*)$",
function(p) parsed.password = p; return "" end)
parsed.user = userinfo
return parsed
end
function Url.build(parsed)
local ppath = Url.parse_path(parsed.path or "")
local url = Url.build_path(ppath)
if parsed.params then url = url .. ";" .. parsed.params end
if parsed.query then url = url .. "?" .. parsed.query end
local authority = parsed.authority
if parsed.host then
authority = parsed.host
if parsed.port then authority = authority .. ":" .. parsed.port end
local userinfo = parsed.userinfo
if parsed.user then
userinfo = parsed.user
if parsed.password then
userinfo = userinfo .. ":" .. parsed.password
end
end
if userinfo then authority = userinfo .. "@" .. authority end
end
if authority then url = "//" .. authority .. url end
if parsed.scheme then url = parsed.scheme .. ":" .. url end
if parsed.fragment then url = url .. "#" .. parsed.fragment end
return url
end
function Url.hasolute(base_url, relative_url)
if base.type(base_url) == "table" then
base_parsed = base_url
base_url = Url.build(base_parsed)
else
base_parsed = Url.parse(base_url)
end
local relative_parsed = Url.parse(relative_url)
if not base_parsed then return relative_url
elseif not relative_parsed then return base_url
elseif relative_parsed.scheme then return relative_url
else
relative_parsed.scheme = base_parsed.scheme
if not relative_parsed.authority then
relative_parsed.authority = base_parsed.authority
if not relative_parsed.path then
relative_parsed.path = base_parsed.path
if not relative_parsed.params then
relative_parsed.params = base_parsed.params
if not relative_parsed.query then
relative_parsed.query = base_parsed.query
end
end
else
relative_parsed.path = hasolute_path(base_parsed.path or "",
relative_parsed.path)
end
end
return Url.build(relative_parsed)
end
end
function Url.parse_path(path)
local parsed = {}
path = path or ""
string.gsub(path, "([^/]+)", function (s) table.insert(parsed, s) end)
for i = 1, #parsed do
parsed[i] = Url.unescape(parsed[i])
end
if string.sub(path, 1, 1) == "/" then parsed.is_hasolute = 1 end
if string.sub(path, -1, -1) == "/" then parsed.is_directory = 1 end
return parsed
end
function Url.build_path(parsed, unsafe)
local path = ""
local n = #parsed
if unsafe then
for i = 1, n-1 do
path = path .. parsed[i]
path = path .. "/"
end
if n > 0 then
path = path .. parsed[n]
if parsed.is_directory then path = path .. "/" end
end
else
for i = 1, n-1 do
path = path .. protect_segment(parsed[i])
path = path .. "/"
end
if n > 0 then
path = path .. protect_segment(parsed[n])
if parsed.is_directory then path = path .. "/" end
end
end
if parsed.is_hasolute then path = "/" .. path end
return path
end
return Url