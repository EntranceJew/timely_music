AddCSLuaFile()

local function truthString(x)
  if x then return language.GetPhrase("active") else return language.GetPhrase("inactive") end
end

local cv = TimelyMusic.ConVars

-- local ucwords = function(str)
  -- str = str:gsub("_+", " ")
  -- return str:gsub("(%a)([%w]*)", function(first, rest) return first:upper() .. rest:lower() end)
-- end
local function handleMenu(panel, data, prefix)
  -- local title = ucwords(data[2])
  local varname = prefix .. data[2]
  local el = nil

  local tstring = "#" .. string.lower(TimelyMusic.ConVars.meta.title) .. "." .. varname .. ".title"
  local dstring = "#" .. string.lower(TimelyMusic.ConVars.meta.title) .. "." .. varname .. ".description"
  -- TimelyMusic.PropText = TimelyMusic.PropText .. "\n" .. string.lower(TimelyMusic.ConVars.meta.title) .. "." .. varname .. ".title=" .. title
  -- TimelyMusic.PropText = TimelyMusic.PropText .. "\n" .. string.lower(TimelyMusic.ConVars.meta.title) .. "." .. varname .. ".description=" .. data[3]

  if data[1] == "category" then
    local pan = vgui.Create("DForm")
    pan:SetName(dstring)
    for i = 1, #data[4] do
      local v = data[4][i]
      handleMenu(pan, v, prefix)
    end
    panel:AddItem(pan)
    el = pan
  elseif data[1] == "themeselect" then
    TimelyMusic.ListView = vgui.Create( "DListView")
    for i, col in pairs(data[4]) do
      -- local cstring = string.lower(TimelyMusic.ConVars.meta.title) .. "." .. varname .. ".col" .. i .. "=" .. col
      local cstring = "#" .. string.lower(TimelyMusic.ConVars.meta.title) .. "." .. varname .. ".col" .. i
      TimelyMusic.PropText = TimelyMusic.PropText .. "\n" .. cstring
      TimelyMusic.ListView:AddColumn( cstring )
    end
    TimelyMusic.ListView:GetDataHeight()
    TimelyMusic.ListView:SetTall(22 + math.min(TimelyMusic.ListView:DataLayout(), 160))
    TimelyMusic.ListView:SetMultiSelect( false )

    TimelyMusic.ListView.DoDoubleClick = function( lst, lineID, linePanel )
      local key = linePanel:GetColumnText( 1 )
      TimelyMusic.EnabledThemes[key] = not TimelyMusic.EnabledThemes[key]

      -- RunConsoleCommand("sv_loc_toggle_currency", key, truthNumber(TimelyMusic.EnabledDenominations[key]))
      linePanel:SetColumnText( 2, truthString(TimelyMusic.EnabledThemes[key]) )

      TimelyMusic.SaveThemes()
      TimelyMusic.RefreshListView()
    end

    TimelyMusic.RefreshListView()
    panel:AddItem(TimelyMusic.ListView)
    el = TimelyMusic.ListView
  elseif data[1] == "bool" then
    el = panel:CheckBox( tstring, varname )
  elseif data[1] == "button" then
    el = vgui.Create( "DButton" )
    el:SetText( tstring )
    -- label:SetTextColor( Color( 0, 0, 0 ) )
    if type( data[4] ) == "function" then
      el.DoClick = data[4]
    else
      el.DoClick = function()
        for k2, v2 in pairs(data[4]) do
          RunConsoleCommand( k2, v2 )
        end
      end
    end
    panel:AddItem(el)
  elseif data[1] == "string" then
    el = panel:TextEntry(tstring, varname )
  elseif data[1] == "float" then
    local min = data[5] or 0
    local max = data[6] or data[4]
    if data[6] == nil then
      max = math.pow(max, 1.25)
    end
    el = panel:NumSlider( tstring, varname, min, max )
  end
  if data[1] ~= "category" then
    if el ~= nil then
      local tip = varname
      if data[4] ~= nil and type(data[4]) ~= "table" and type(data[4]) ~= "function" then
        tip = tip .. "\n" .. language.GetPhrase("#default") .. ": " .. data[4]
      end
      el:SetTooltip(tip)
    end
    panel:ControlHelp(dstring)
  end
end
hook.Add( "PopulateToolMenu", cv.meta.title .. "_CustomMenuSettings", function()
  for tm = 1, #cv.toolmenus do
    local tmenu = cv.toolmenus[tm]
    spawnmenu.AddToolMenuOption(
        tmenu.tab,
        tmenu.heading,
        cv.meta.title .. "_" .. tmenu.heading .. "Options",
        tmenu.titlebar, "", "", function( panel )
          for i = 1, #tmenu.contents do
            local c = tmenu.contents[i]
            handleMenu(panel, c, tmenu.prefix .. "_" .. cv.meta.prefix .. "_")
          end
          panel:Help("")
    end)
  end
  -- file.Write( string.lower(cv.meta.title) .. ".txt", TimelyMusic.PropText )
end)
