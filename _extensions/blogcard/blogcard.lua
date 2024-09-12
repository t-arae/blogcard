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

--Fill the OGPdata members with data from meta tag
--@param meta string A string inside the <meta ..>
function OGPdata:fill_from_meta(meta)
  local get_pattern = function(k)
    return "property=\"og:" .. k .. "\" content=\"(.-)\""
  end

  for k, _ in pairs(self) do
    local p = get_pattern(k)
    local v = meta:match(p)
    if v ~= nil then
      self[k] = v
    end
  end
end

function constract_ogp_data(metas, url)
  local ogp = OGPdata:new()
  ogp["link"] = url
  for m in metas do
    if m:match("property=\"og") then
      ogp:fill_from_meta(m)
    end
  end
  return ogp
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

--- Filter ---

return {
  ['blogcard'] = function(args, kwargs, meta) 
    local url = ""
    url = pandoc.utils.stringify(kwargs["url"])
    if url == "" then
      url = args[1]
    end
    local str_head = extract_inside_head(url)
    local gen_str_meta = get_inside_meta(str_head)
    local ogp = constract_ogp_data(gen_str_meta, url)
    ogp:fill_from_kwargs(kwargs)
    ogp:print()

    if quarto.doc.isFormat('html') then
      local t = quarto.utils.resolve_path("assets/template1.html")
      local compiled = compile_template(t, ogp)
      return pandoc.RawBlock("html", compiled)
    else
      -- fall back to insert a form feed character
      return pandoc.Link(url, url)
    end
  end
}
