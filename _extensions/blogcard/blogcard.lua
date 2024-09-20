--- Functions for getting HTML data ---

--Extract the inside text in the head tag from Web page
--@param url string An URL want to make blog card
--@return string An string inside the <head> .. </head>
function extract_inside_head(url)
  local status, mt, contents = pcall(pandoc.mediabag.fetch, url)
  if not status then
    return "<meta >"
  end
  -- print("head: ", string.match(contents, "<head.->(.-)</head>"))
  return string.match(contents, "<head.->(.-)</head>")
end

--Get a generator generates inside string in meta tags from the string inside head tag 
--@param in_head string A string inside the <head> .. </head>
--@return func()->string A generator function returns string inside the <meta ..>
function get_inside_meta(in_head)
  local f = string.gmatch(in_head, "<meta (.-)>")
  return f
end

function extract_all_meta_tags(in_head)
  local pos = 1
  local meta_tags = {}
  while true do
      local start_pos, end_pos = in_head:find("<meta%s", pos)
      if not start_pos then
          break  -- 全ての<meta>タグを検索済み
      end

      local in_quote = false
      local quote_char = ''
      local i = end_pos + 1
      while i <= #in_head do
          local char = in_head:sub(i,i)
          if not in_quote and (char == '"' or char == "'") then
              in_quote = true
              quote_char = char
          elseif in_quote and char == quote_char then
              in_quote = false
          elseif not in_quote and char == '>' then
              local meta_tag = in_head:sub(start_pos, i)
              table.insert(meta_tags, meta_tag)
              pos = i + 1
              break
          end
          i = i + 1
      end
      pos = end_pos + 1
  end
  return meta_tags
end

--- OGPdata: Data for the Open Graph Protocol ---

OGPdata = {}

--Constructor for OGPdata
--@return OGPdata An initialized OGPdata instance
function OGPdata:new()
  newObj = {link = "", title = "", description = "", image = "", site_name = ""}
  self.__index = self
  return setmetatable(newObj, self)
end

--Print members
function OGPdata:print()
  for k, v in pairs(self) do
    print(k .. ": " .. v)
  end
  print ""
end

--Fill the OGPdata members with data from keyword args
--@param kwargs table<any, any> keyword args
function OGPdata:fill_from_kwargs(kwargs)
  for k, _ in pairs(self) do
    local v = ""
    v = pandoc.utils.stringify(kwargs[k])
    if v ~= "" then
      print("[" .. k .. "]: " .. v)
      self[k] = v
    end
  end
end

function extract_value(s)
  local i = 1
  local len = #s
  local result = ''
  local escaping = false

  local c = s:sub(i, i)
  local quote = c
  i = i + 1

  while i <= len do
    c = s:sub(i, i)
    if c == "\\" then
      escaping = true
    elseif c == quote then
      if escaping then
        result = result .. "\\" .. c
        escaping = false
      else
        break
      end
    else
      result = result .. c
    end
    i = i + 1
  end
  return result
end

--print(extract_value('"hello \\"world" !!'))
--print(extract_value("'hello \\'world' !!"))

--Fill the OGPdata members with data from meta tag
--@param meta string A string inside the <meta ..>
function OGPdata:fill_from_meta(metas)
  local get_pattern = function(k)
    --return "property=\"og:" .. k .. "\".- content=\"(.-)\""
    return "property=\"og:" .. k .. "\".- content=([\"'].*)"
  end

  local lines = {}
  for _, meta in pairs(metas) do
    table.insert(lines, meta)
  end
  local metas_cat = table.concat(lines, "\n")

  for k, _ in pairs(self) do
    local p = get_pattern(k)
    local v = metas_cat:match(p)
    if v ~= nil then
      self[k] = extract_value(v)
    end
  end
end

local get_url_path = function(url)
  if url:match("[#]") then
    url = url:match("^(.*)[#]")
  end
  return url
end

local get_favicon_link = function(x, url, isfile)
  -- check whether the favicon URL is absolute or not
  local is_absolute = function(x)
    return (string.find(x, "^http")) and true or false
  end

  -- extract favicon link
  -- rel="(shortcut ){0,1}icon"
  local link_favicon = x:match("<link([^>]- rel=\"[^\"]-icon\"[^>]-)>") or ""
  link_favicon = link_favicon:match("href=\"(.-)\"") or ""
  
  if link_favicon ~= "" then
    if (not is_absolute(link_favicon)) then
      local resource_dir = isfile and pandoc.path.directory(url) or url
      if (string.match(link_favicon, "^/")) then
        print("Here !!!")
        link_favicon = link_favicon:match("^/*(.*)")
        resource_dir = resource_dir:match("(https-://[^/]-/)")
      end
      resource_dir = get_url_path(resource_dir)
      if resource_dir:match("[#]") then
        resource_dir = resource_dir:match("^(.*)[#]")
      end
      link_favicon = pandoc.path.join({resource_dir, pandoc.path.normalize(link_favicon)})
    end
  else
    link_favicon = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAAAAACo4kLRAAAAL0lEQVR42mP4jwUwUEeQAQTQBBkYkEUZkMVgogwoYlBRmglitR27O7H7iCZBhwIAfn4t4TicsrEAAAAASUVORK5CYII="
  end

  return link_favicon
end

--- Functions for templates ---

--Read template
--Note: If the pandoc version >= 3.2.1, `pandoc.template.get()` should be able to use instead.
--@param filename string A path for the template
--@return string content of template
local function read_lines(filename)
  local lines = {}
  for i in io.lines(filename) do
    table.insert(lines, i)
  end
  return table.concat(lines, "\n")
end

--Compile template with vars in the context
--@param filename string A path for the template
--@param context table<any, any>
--@return string a compile and applied template string
local function compile_template(filename, context)
  local content = read_lines(filename)
  local compiled = pandoc.template.compile(content)
  local rendered = pandoc.template.apply(compiled, context):render()
  return rendered
end

function dump(o)
  if type(o) == 'table' then
     local s = '{\n    '
     for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ',\n    '
     end
     return s .. '}\n    '
  else
     return tostring(o)
  end
end

function load_templates(asset_dir)
  if asset_dir == nil then
    asset_dir = quarto.utils.resolve_path("assets")
  end

  local templates = {}
  for _, v in pairs(pandoc.system.list_directory(asset_dir)) do
    local temp_dir = pandoc.path.join({asset_dir, v})
    local temp_table = {}
    for _, u in pairs(pandoc.system.list_directory(temp_dir)) do
      local k = u:match("[a-z]-$")
      temp_table[k] = pandoc.path.join({temp_dir, u})
    end
    templates[v] = temp_table
  end
  return templates
end

-- print(dump(load_templates()))
Templates = load_templates()

Template = {}
function Template:new()
  newObj = {tname = "", html = "", css = ""}
  self.__index = self
  return setmetatable(newObj, self)
end

function Template:set_default(key)
  self.tname = key
  for k, v in pairs(Templates[key]) do
    self[k] = v
  end
end

function Template:get_tname()
  return self.tname
end

function Template:get_html()
  return self.html
end

function Template:get_css()
  return {self.css}
end

--- Filter ---

return {
  ['blogcard'] = function(args, kwargs, meta) 
    local url = ""
    url = pandoc.utils.stringify(kwargs["url"])
    if url == "" then
      url = args[1]
    end
    local str_head = extract_inside_head(url)
    --local gen_str_meta = get_inside_meta(str_head)
    local gen_str_meta = extract_all_meta_tags(str_head)
    local ogp = OGPdata:new()
    ogp["link"] = url

    local isfile = false
    local kwarg_isfile = pandoc.utils.stringify(kwargs["isfile"])

    local url_path = get_url_path(url)
    isfile = (url_path:match("html$")) and true or false
    isfile = kwarg_isfile == "true" and true or isfile
    isfile = kwarg_isfile == "false" and false or isfile

    print("kwargs.isfile: " .. kwarg_isfile)
    print("isfile: ", isfile)

    ogp["favicon"] = get_favicon_link(str_head, url, isfile)
    ogp:fill_from_meta(gen_str_meta)
    ogp:fill_from_kwargs(kwargs)
    ogp:print()

    if quarto.doc.isFormat('html') and quarto.doc.has_bootstrap() then
      local tname = ""
      tname = pandoc.utils.stringify(kwargs["tname"])
      if tname == "" then
        tname = "default"
      end
      local t = Template:new()
      t:set_default(tname)

      quarto.doc.addHtmlDependency({
        name = t:get_tname(),
        version = "1.0.0",
        stylesheets = t:get_css()
      })
      local compiled = compile_template(t:get_html(), ogp)
      return pandoc.RawBlock("html", compiled)
    else
      -- fall back to insert a form feed character
      return pandoc.Link(url, url)
    end
  end
}
