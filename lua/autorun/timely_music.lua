AddCSLuaFile()
if not CLIENT then return end

local addons = engine.GetAddons()

local print = function(...)
  if GetConVar("cl_tim_debug_enable"):GetBool() then
    local out = {...}
    table.insert(out, 1, "TimelyMusic:")
    print(unpack(out))
  end
end
local wrapto = function(val, size)
  return (val % (#size)) + 1
end
local slugify = function(str, replacement)
  replacement = replacement or "_"
  local out = {}
  for k in string.gmatch(str, "(%w+)") do
    table.insert(out, k)
  end
  return table.concat(out, replacement):lower()
end
NOTIFY_SOUND = 5
NoticeMaterial2 = {}
NoticeMaterial2[ NOTIFY_GENERIC ]	= Material( "vgui/notices/generic" )
NoticeMaterial2[ NOTIFY_ERROR ]		= Material( "vgui/notices/error" )
NoticeMaterial2[ NOTIFY_UNDO ]		= Material( "vgui/notices/undo" )
NoticeMaterial2[ NOTIFY_HINT ]		= Material( "vgui/notices/hint" )
NoticeMaterial2[ NOTIFY_CLEANUP ]	= Material( "vgui/notices/cleanup" )
NoticeMaterial2[ NOTIFY_SOUND ]	= Material( "vgui/notices/sound" )
vgui.GetControlTable("NoticePanel").SetLegacyType = function(self, t)
  self.Image = vgui.Create( "DImageButton", self )
  self.Image:SetMaterial( NoticeMaterial2[ t ] )
  self.Image:SetSize( 32, 32 )
  self.Image:Dock( LEFT )
  self.Image:DockMargin( 0, 0, 8, 0 )
  self.Image.DoClick = function()
    self.StartTime = 0
  end

  self:SizeToContents()
end
/*
  -- TODO:
  -- TODO: manual path overrides to re-assign song paths
  -- TODO: manual NPC class overrides
  -- TODO: song_end event for resolvers that pick a new track instead of looping
  -- TODO: scan and load all file names, if a duplicate file is found in the same addon, refuse to load it
  -- TODO: scan and load all
  -- TODO: implement MTI:Path() for use in content loader scripts
  -- TODO: weather chain for "Clear" sometimes becomes {"Clear", "Fog", "Clear"}
  -- TODO: PvP detection / death music
  -- TODO: add server-sided component for reporting witnesses
*/
local join_time = nil
local is_reload = false
if TimelyMusic then
  is_reload = true
  join_time = SysTime()
end

local con_struct = {
  meta = {
    prefix = "tim",
    title = "TimelyMusic",
  },
  toolmenus = {
    {
      tab = "Utilities",
      heading = "User",
      uid = "TimelyMusic_UserOptions",
      titlebar = "Timely Music",
      prefix = "cl",
      sets = {FCVAR_ARCHIVE},
      contents = {
        {"category", "general", "General", {
          {"themeselect", "enabled_themes", "Double-click to enable / disable music themes.", {"Theme", "Active?"}},
          {"bool", "enabled", "Should we be playing music at all?", 1, 0, 1},
          {"bool", "notifications", "Should we show notifications on track changes?", 1, 0, 1},
          {"float", "volume", "How loud should we be playing?", 1, 0.0, 1.0},
          {"float", "crossfade_time", "How many in-game minutes should a crossfade take to complete?", 5.0, 0.0, nil},
          {"bool", "no_zero_length", "Should we ignore tracks that have no length?", 1, 0, 1},
          {"button", "reload", "Should we reload TimelyMusic to refresh installed music packs? Useful for debugging packs you're working on.", {"timelymusic_reload"}},
          {"button", "track_change", "Sends an event that refreshes the track.", function()
            TimelyMusic:SendEvent("track_change", TimelyMusic.State)
          end},
        }},
        {"category", "features", "Features", {
          {"bool", "feature_hourly", "Should we allow the use of hourly music?", 1, 0, 1},
          {"bool", "feature_weather", "Should we allow the use of weather-based music?", 1, 0, 1},
          {"bool", "feature_ambient", "Should we allow the use of ambient music? Disabling will make things silent when out of combat.", 1, 0, 1},
          {"bool", "feature_combat", "Should we allow the use of music based on combat status? Disabling will result in only ambient music being played.", 1, 0, 1},
          {"bool", "feature_combat_classes", "Should we allow the use of music based on the class of combat enemies? Disabling will result in pooling all combat music together randomly.", 1, 0, 1},
          {"bool", "feature_map_specific", "Should we allow the use of map-specific music?", 1, 0, 1},
        }},
        {"category", "battle", "Battle", {
          {"bool", "battle_los_required", "Should we be in line of sight for NPC battle?", 1, 0, 1},
          {"float", "battle_decay_time", "How long should we wait before ending combat music after enemies lose sight?", 5.0, 0.0, nil},
          {"float", "battle_check_interval", "How frequently should we check if we're in combat?", 0.5, 0.0, nil},
        }},
        {"category", "debug", "Debug", {
          {"bool", "notifications_debug", "Should we show extra info with our track change notifications?", 0, 0, 1},
          {"bool", "debug_enable", "Should we be using extra debug prints?", 0, 0, 1},
        }},
      },
    },
  }
}

for tm = 1, #con_struct.toolmenus do
  local tmenu = con_struct.toolmenus[tm]
  for i = 1, #tmenu.contents do
    local cm = tmenu.contents[i]
    for j = 1, #cm[4] do
      local v = cm[4][j]
      if v[1] ~= "themeselect" and v[1] ~= "button" then
        CreateConVar(
          tmenu.prefix .. "_" .. con_struct.meta.prefix .. "_" .. v[2],
          v[4],
          tmenu.sets,
          v[3],
          v[5],
          v[6]
        )
      end
    end
  end
end

TimelyMusic = {
  -- [[ static variables ]]
  -- [[ public data ]]
  PropText = "",
  ConVars = con_struct,
  FeatureNames = {
    "hourly_music",
    "concurrent_weather",
  },
  EventNames = {
    "combat_start",
    "combat_end",
    "hour_changed",
    "weather_changed",
  },

  NPCClassTags = {
    {
      "bosses",
      {
        "npc_advisor",
        "npc_combinegunship",
        "npc_helicopter",
        "npc_hunter",
        "npc_strider",
        "monster_gargantua",
        "monster_bigmomma",
        "monster_nihilanth",
        "monster_tentacle",
        -- Hmm
        ".garg.",
        ".gonarch*",
        ".bigmomma*",
        ".nihil.",
        ".conquest.",
        ".boss.",
        ".kurome.",
      },
    },
    {
      "soldiers",
      {
        "npc_apcdriver",
        "npc_combine_s",
        "monster_human_grunt",
        "monster_human_assassin",
        "monster_turret",
        "monster_sentry",
        "monster_miniturret",
        -- "npc_metropolice",
        -- Hmm
        ".marine.",
      },
    },
    {
      "cops",
      {
        "npc_metropolice",
        -- "npc_citizen",
      }
    },
    {
      "aliens",
      {
        "npc_antlion",
        "npc_antlionworker",
        "npc_antlionguard",
        "npc_fastzombie",
        "npc_fastzombie_torso",
        "npc_poisonzombie",
        "npc_zombie",
        "monster_zombie",
        "monster_houndeye",
        "monster_alien_grunt",
        "monster_alien_slave",
        "monster_bullchicken",
        "monster_alien_controller",
        "npc_zombie_torso",
        "npc_zombine",
        -- Hmm
        ".alien.",
        ".zombie.",
      },
    },
    {
      "warning",
      {
        "npc_barnacle",
        "monster_barnacle",
        "combine_mine",
        "npc_clawscanner",
        "npc_combine_camera",
        "npc_combinedropship",
        "npc_cscanner",
        "npc_headcrab",
        "monster_headcrab",
        "monster_snark",
        "npc_manhack",
        "npc_rollermine",
        "npc_sniper",
        "npc_turret_ceiling",
        "npc_turret_floor",
        "npc_turret_ground",
        "npc_stalker",
        "npc_headcrab_black",
        "npc_headcrab_fast",
      },
    },
  },

  LastFilePath = nil,

  BattleCheckTime = 0.5,

  Themes = {},
  EnabledThemes = {},

  State = {},
  PreviousState = nil,

  WeatherChains = {},
  WeatherFallbacks = {},

  Tracks = {},
  ActiveTrack = 1,
  TrackCache = {},
  ResolveTableCache = {},

  ChainBreakCount = 0,

  ListView = TimelyMusic and TimelyMusic.ListView or nil,

  -- [[ static methods ]]
  GetTime = function()
    local d = os.date("*t")
    d.hour = 0
    d.min  = 0
    d.sec  = 0

    -- scale things to from 0=>86400 to 0=>1440
    return (os.time() - os.time(d)) / 60
  end,

  -- [[ class methods ]]
  BakeChains = function()
    TimelyMusic.WeatherFallbacks = {}
    TimelyMusic.WeatherChains = {}

    if not (StormFox2 and StormFox2.Weather and StormFox2.Weather.GetAll) then return end
    local wets = StormFox2.Weather.GetAll()
    for _,name in ipairs(wets) do
      local w = StormFox2.Weather.Get(name)
      if TimelyMusic.WeatherFallbacks[w.Name] == nil and w.Inherit then
        TimelyMusic.WeatherFallbacks[w.Name] = w.Inherit
      end
    end

    for k, v in pairs(TimelyMusic.WeatherFallbacks) do
      local wn = k
      local chain = {}
      while TimelyMusic.WeatherFallbacks[wn] ~= nil do
        wn = TimelyMusic.WeatherFallbacks[wn]
        table.insert(chain, wn)
      end
      if #chain >= 1 then
        TimelyMusic.WeatherChains[k] = chain
      end
    end
  end,

  AddTheme = function(theme_name, theme_table)
    TimelyMusic.EnabledThemes[theme_name] = true
    TimelyMusic.Themes[theme_name] = theme_table
  end,

  IsSpecialFolder = function(dir_name)
    return dir_name == "maps" or
            dir_name == "combat" or
            dir_name == "ambient" or
            dir_name == "weather" or
            dir_name == "hourly"
  end,

  PathToNode = function(resolve_global, resolve_chain, start_path)
    local root_files, root_dirs = file.Find( start_path .. "/*", "GAME" )
    local t = {}
    /*
      important node keys:
        type = the key that reflects how the GetMusicForCondition should handle the node
        next = the next table to process in this chain
    */

    for _, root_dir in ipairs(root_dirs) do
      local node_files, node_dirs = file.Find( start_path .. "/" .. root_dir .. "/*", "GAME" )
      local path = start_path .. "/" .. root_dir

      if root_dir == "maps" then
        local maps = {}
        local found_maps = 0
        for _, node_dir in ipairs(node_dirs) do
          if not TimelyMusic.IsSpecialFolder(node_dir) then
            maps[node_dir] = TimelyMusic.PathToNode(reserve_global, resolve_chain, path .. "/" .. node_dir)
            found_maps = found_maps + 1
          end
          -- TODO: [dig] handle if there ARE special folders in maps
          -- TODO: [dig] handle loose files in maps?
        end

        if found_maps > 0 then
          t.maps = maps
        end
      end

      if root_dir == "combat" then
        local classes = {}
        local found_classes = 0
        for _, node_dir in ipairs(node_dirs) do
          if not TimelyMusic.IsSpecialFolder(node_dir) then
            classes[node_dir] = TimelyMusic.PathToNode(reserve_global, resolve_chain, path .. "/" .. node_dir)
            found_classes = found_classes + 1
          end
          -- TODO: [dig] handle if there ARE special folders in combat
        end

        if found_classes > 0 then
          t.combat_classes = classes
        end

        if #node_files > 0 then
          t.combat = {}
          for _, node_file in ipairs(node_files) do
            table.insert(t.combat, path .. "/" .. node_file)
          end
        end
      end

      if root_dir == "ambient" then
        t.ambient = TimelyMusic.PathToNode(resolve_global, resolve_chain, path )
      end

      if root_dir == "weather" then
        local weather = {}
        local found_weather = 0
        for _, node_dir in ipairs(node_dirs) do
          if not TimelyMusic.IsSpecialFolder(node_dir) then
            weather[node_dir] = TimelyMusic.PathToNode(reserve_global, resolve_chain, path .. "/" .. node_dir)
            found_weather = found_weather + 1
          end
          -- TODO: [dig] handle if there ARE special folders in maps
          -- TODO: [dig] handle loose files in maps?
        end

        if found_weather > 0 then
          t.weather = weather
        end

        /*
          -- why did i do this
          if #node_files > 0 then
            t.weather_loose = {}
            for _, node_file in ipairs(node_files) do
              table.insert(t.weather_loose, path .. "/" .. node_file)
            end
          end
        */
      end

      if root_dir == "hourly" then
        t.hourly = TimelyMusic.PathToNode(resolve_global, resolve_chain, path )
      end
    end

    -- if #root_files > 0 then return root_files end
    -- TODO: maybe we should drop this into a "misc" property?
    for _, root_file in ipairs(root_files) do
      table.insert(t, start_path .. "/" .. root_file)
    end

    return t
  end,

  ResolveNode = function(node, event_name, event_data)
    -- RESOLVE: maps/
    if node.maps and node.maps[event_data.map] and GetConVar("cl_tim_feature_map_specific"):GetBool() then
      return TimelyMusic.ResolveNode(node.maps[event_data.map], event_name, event_data)
    end

    -- RESOLVE: combat/*/
    if event_data.in_combat and node.combat_classes and GetConVar("cl_tim_feature_combat_classes"):GetBool() and GetConVar("cl_tim_feature_combat"):GetBool() then
      for l = 1, #TimelyMusic.NPCClassTags do
        local tag = TimelyMusic.NPCClassTags[l][1]
        local comb = node.combat_classes
        if event_data.combat_tags[ tag ] and comb and comb[tag] and #comb[tag] > 0 then
          return TimelyMusic.ResolveNode(comb[tag], event_name, event_data)
        end
      end
    end

    -- RESOLVE: combat/*.ext
    if event_data.in_combat and node.combat and GetConVar("cl_tim_feature_combat"):GetBool() then
      return TimelyMusic.ResolveNode(node.combat, event_name, event_data)
    end

    -- RESOLVE: ambient/
    if not event_data.in_combat and node.ambient and GetConVar("cl_tim_feature_ambient"):GetBool() then
      return TimelyMusic.ResolveNode(node.ambient, event_name, event_data)
    end

    -- RESOLVE: weather/
    if node.weather and GetConVar("cl_tim_feature_weather"):GetBool() then
      for _, wname in ipairs(event_data.weather_chain) do
        if node.weather[wname] then
          return TimelyMusic.ResolveNode(node.weather[wname], event_name, event_data)
        end
      end

      /*
        -- literally what was i thinking
        if node.weather_loose and #node.weather_loose > 0 then
          return TimelyMusic.ResolveNode(node.weather_loose, event_name, event_data)
        end
      */
    end

    -- RESOLVE: hourly/%d%d.wav
    if node.hourly and GetConVar("cl_tim_feature_hourly"):GetBool() and node.hourly[event_data.time_hours] then
      return node.hourly[event_data.time_hours]
    end

    -- RESOLVE: /*
    if type(node) == "table" and #node > 0 then
      local table_memory = tostring(node)
      TimelyMusic.ResolveTableCache[table_memory] = wrapto((TimelyMusic.ResolveTableCache[table_memory] or 0) + 1, node)
      -- TODO: maybe don't use the random here
      return node[ math.random(TimelyMusic.ResolveTableCache[table_memory]) ]
    end
  end,

  AssembleTracks = function()
    local _ = nil
    local themes = {}
    addons = engine.GetAddons()

    -- TASK: hoover up timely_music tracks
    _, themes = file.Find( "sound/timely_music/*", "GAME" )
    for i = 1, #themes do
      local theme = themes[i]
      if TimelyMusic.Themes[theme] ~= nil then continue end
      local tdata = TimelyMusic.PathToNode({}, {}, "sound/timely_music/" .. theme)
      tdata.ambient_i = 1.0

      tdata.GetMusicForCondition = function(self, event_name, event_data)
        return TimelyMusic.ResolveNode(self, event_name, event_data)
      end

      TimelyMusic.AddTheme(theme, tdata)
    end

    -- TASK: hoover up NOMBAT tracks
      -- "sound/nombat/jakii/a1.mp3"
     _, themes = file.Find( "sound/nombat/*", "GAME" )
    for i = 1, #themes do
      local theme = themes[i]
      if TimelyMusic.Themes[theme] ~= nil then continue end
      local tdata = {}

      tdata.ambient_i = 1.0
      tdata.csongs = {
        ambient = {},
        combat = {},
      }
      local files = file.Find( "sound/nombat/" .. theme .. "/*", "GAME" )
      for _, filename in ipairs(files) do
        print("forcing this", filename)
        local songtype = string.sub(filename, 1, 1)
        local fullpath = "sound/nombat/" .. theme .. "/" .. filename
        if songtype == "a" then
          table.insert(tdata.csongs.ambient, fullpath)
        elseif songtype == "c" then
          table.insert(tdata.csongs.combat, fullpath)
        else
          print("found a wacky nombat song:", fullpath)
        end
      end
      tdata.GetMusicForCondition = function(self, event_name, event_data)
        if event_name == "combat_start" and #tdata.csongs.combat > 0 then
          return self.csongs.combat[ math.random( #self.csongs.combat ) ]
        elseif not event_data.in_combat and (event_name == "hour_changed" or event_name == "weather_changed" or event_name == "combat_end") then
          tdata.ambient_i = wrapto(tdata.ambient_i + 1, tdata.csongs.ambient)
          return tdata.csongs.ambient[tdata.ambient_i]
        end
      end
      TimelyMusic.AddTheme(theme, tdata)
    end

    for i = 1, #addons do
      local addon = addons[i]
      local theme_name = slugify(addon.title)
      if TimelyMusic.Themes[theme_name] ~= nil then
        continue
      end
      local seek_spots = {
        "ayykyu_dynmus",
        "battlemusic"
      }
      local tdata = {}
      tdata.ambient_i = 1.0
      tdata.csongs = {
        ambient = {},
        combat = {},
        all_combat = {},
      }
      local found = 0
      for m = 1, #seek_spots do
        local seek = seek_spots[m]
        local f, d = file.Find("sound/" .. seek .. "/*", addon.title)
        if (#f > 0 or #d > 0) then
          local files = file.Find("sound/" ..  seek .. "/ambient/*", addon.title )
          for _, filename in ipairs(files) do
            found = found + 1
            local fullpath = "sound/" .. seek .. "/ambient/" .. filename
            print("dynamo/sbm ambient", fullpath)
            table.insert(tdata.csongs.ambient, fullpath)
          end

          local _, categories = file.Find( "sound/" .. seek .. "/combat/*", addon.title )
          for j = 1, #categories do
            local category = categories[j]
            if tdata.csongs.combat[category] == nil then
              tdata.csongs.combat[category] = {}
            end

            files = file.Find( "sound/" .. seek .. "/combat/" .. category .. "/*", addon.title )
            for _, filename in ipairs(files) do
              found = found + 1
              local fullpath = "sound/" .. seek .. "/combat/" .. category .. "/" .. filename
              print("dynamo/sbm combat", fullpath)
              table.insert(tdata.csongs.combat[category], fullpath)
              table.insert(tdata.csongs.all_combat, fullpath)
            end
          end
          tdata.GetMusicForCondition = function(self, event_name, event_data)
            if event_name == "combat_start" then
              for l = 1, #TimelyMusic.NPCClassTags do
                local tag = TimelyMusic.NPCClassTags[l][1]
                local comb = self.csongs.combat
                if event_data.combat_tags[ tag ] and comb and comb[tag] and #comb[tag] > 0 then
                  return comb[tag][ math.random( #comb[tag] ) ]
                end
              end
              -- TODO: make an option to return any if we reach this point
              -- TODO: make an option to use any combat song (nombat feature parity)
              -- return self.csongs.all_combat[ math.random( #self.csongs.all_combat ) ]
            elseif not event_data.in_combat and (event_name == "hour_changed" or event_name == "combat_end" or event_name == "weather_changed") then
              tdata.ambient_i = wrapto(tdata.ambient_i + 1, tdata.csongs.ambient)
              return tdata.csongs.ambient[tdata.ambient_i]
            end
          end
        end
      end
      if found > 0 then
        TimelyMusic.AddTheme(theme_name, tdata)
      end
    end

    -- TODO: other music addons?
  end,
  GetCrossFadeDuration = function()
    return GetConVar("cl_tim_crossfade_time"):GetFloat()
  end,

  GetActiveTrack = function(self)
    return self.Tracks[self.ActiveTrack]
  end,

  PlayTrack = function(self, filename)
    TimelyMusic.TrackClass:new(filename, {
      PlayOnAwake = true,
    })
  end,

  MuteAllBut = function(self, track, fadetime)
    for i = 1, #self.Tracks do
      local t = self.Tracks[i]
      if t ~= track then
        t.TweenVolumeGoal = 0
        t.TweenVolumeStart = t.InternalVolume
        t.TweenVolumeBegin = CurTime()
        t.TweenVolumeDuration = fadetime
        t.DeleteAfter = CurTime() + fadetime
      end
    end
  end,

  GetEnabledThemes = function(self)
    local r = {}
    for k, v in pairs(self.Themes) do
      if self.EnabledThemes[k] then
        r[k] = v
      end
    end
    return r
  end,

  SendEvent = function(self, event_name, event_data)
    print("SendEvent", event_name, SysTime() - (join_time or 0))
    if join_time == nil then return false end
    local new_file = self:DecideTrack(event_name, event_data)
    print("DecideTrack said:", new_file)
    if new_file ~= self.LastFilePath and new_file ~= nil then
      print("file was different:", new_file, "and", self.LastFilePath)
      self.LastFilePath = new_file
      self:PlayTrack(new_file)
      return true
    else
      print("file was the same or nil, not playing:", new_file, "and", self.LastFilePath)
    end
    return false
  end,

  DecideTrack = function(self, event_name, event_data)
    local candidates = {}
    local track_name = nil
    local t = self:GetEnabledThemes()
    for k, v in pairs(t) do
      local new_mus = v:GetMusicForCondition(event_name, event_data)
      print("Track Candidats:", k, new_mus)
      local endswithnumber = new_mus ~= nil and new_mus:match("^.+%_(%d+)%..+$")
      if new_mus ~= nil and endswithnumber ~= nil and GetConVar("cl_tim_no_zero_length"):GetBool() and tonumber(endswithnumber) <= 0 then
        new_mus = nil
      end
      if new_mus ~= nil then
        self.TrackCache[k] = new_mus
        table.insert(candidates, k)
      end
    end

    if #candidates > 0 then
      local the_theme = candidates[ math.random( #candidates ) ]
      print("DecideTrack rolled:", self.TrackCache[the_theme], "for theme", the_theme, "of total", #candidates)
      track_name = self.TrackCache[the_theme]
      if track_name == self.LastFilePath then
        return nil
      end

      if GetConVar("cl_tim_notifications"):GetBool() then
        local fn = track_name:match("^.+/(.+)$") or track_name or "ERROR"
        local notif = the_theme .. ": " .. fn
        if GetConVar("cl_tim_notifications_debug"):GetBool() then
          notif = fn .. " [" .. the_theme .. "/" .. event_data.weather .. "/" .. event_data.time_hours .. "]"
        end
        print("Notification was:", notif)

        -- TODO: make this an AddProgress and use it to display track duration
        notification.AddLegacy(notif, NOTIFY_SOUND, 3)
      end
    end
    return track_name
  end,

  LearnWeather = function(self)
    if TimelyMusic.ChainBreakCount > 10 then
      print("============", "ChainBreakCount Shattered!!!", "no more learning about weather names")
      return
    end
    if not (StormFox2 and StormFox2.Weather and StormFox2.Weather.GetCurrent) then return {"Clear"} end
    local _, wn = StormFox2.Weather.GetDescription()
    if TimelyMusic.WeatherChains[wn] ~= nil then
      local shortChain = table.Copy(TimelyMusic.WeatherChains[wn])
      table.insert(shortChain, 1, wn)
      return shortChain
    end
    local cw = StormFox2.Weather.GetCurrent()
    local chain = {}

    if cw.Name ~= wn then
      TimelyMusic.WeatherFallbacks[wn] = cw.Name
    end
    local linkName = wn
    local lastLink = linkName
    local depth = 0
    while TimelyMusic.WeatherFallbacks[linkName] ~= nil or TimelyMusic.WeatherChains[linkName] ~= nil do
      if TimelyMusic.WeatherChains[linkName] ~= nil then
        local newChain = TimelyMusic.WeatherChains[linkName]
        table.Add(chain, newChain)
        linkName = chain[#chain]
      elseif TimelyMusic.WeatherFallbacks[linkName] ~= nil then
        linkName = TimelyMusic.WeatherFallbacks[linkName]
        table.insert(chain, linkName)
      end

      -- in case of emergency
      if lastLink == linkName then
        print("[ERROR] circular chain broken", lastLink, linkName)
        if GetConVar("cl_tim_debug_enable"):GetBool() then
          PrintTable(chain)
        end
        break
      end
      depth = depth + 1
      -- if linkName == "Clear" then
      --   print("monitoring clear chain")
      --   if GetConVar("cl_tim_debug_enable"):GetBool() then
      --     PrintTable(TimelyMusic.WeatherChains)
      --     PrintTable(TimelyMusic.WeatherFallbacks)
      --   end
      -- end
      if depth > 10 then
        print("[ERROR] cyclical depth breakout", lastLink, linkName)
        if GetConVar("cl_tim_debug_enable"):GetBool() then
          PrintTable(chain)
        end
        TimelyMusic.ChainBreakCount = TimelyMusic.ChainBreakCount + 1
        break
      end
    end

    local shortChain = {}
    if #chain >= 1 then
      TimelyMusic.WeatherChains[wn] = chain
      shortChain = table.Copy(TimelyMusic.WeatherChains[wn])
    end
    table.insert(shortChain, 1, wn)
    return shortChain
  end,

  Think = function(self)
    if #self.Tracks > 3 then
      print("too many tracks!!!")
    end

    -- TASK: update the current volume
    for i = #self.Tracks, 1, -1 do
      self.Tracks[i]:Update()
    end

    /*
      if self.current_track then
        local vol = GetConVar("cl_tim_volume"):GetFloat()
        self.current_track:ChangeVolume( vol, 0 )

        if vol == 0 then
          self.current_track:Stop()
          self.current_track = nil
          print("timelymusic: stopped the ambient track, fade away")
        end
      end
    */

    if not GetConVar("cl_tim_enabled"):GetBool() then return end

    self.State = table.Copy(self.PreviousState or {
      combat_start_time = 0,
      combat_tags = {},
    })

    -- TASK: determine the new time and weather
    local t = self.GetTime()
    self.State.map = game.GetMap()
    self.State.time = t
    local h = math.floor(t / 60)
    local m = math.floor(t - (h * 60))
    local the_time = h
    if the_time == 24 then
      the_time = 0
    end
    self.State.time_hours = the_time
    self.State.time_minutes = m
    self.State.time_hours_str = string.format("%02d", the_time)

    -- check if the weather is different within the currently supported theme
    local weatherChain = self:LearnWeather()
    self.State.weather = weatherChain[1]
    self.State.weather_chain = weatherChain

    if self.PreviousState ~= nil and self.State.weather ~= self.PreviousState.weather then
      self:SendEvent("weather_changed", self.State)
    end
    if self.PreviousState ~= nil and self.State.time_hours_str ~= self.PreviousState.time_hours_str then
      self:SendEvent("hour_changed", self.State)
    end

    if self.BattleCheckTime < SysTime() then
      self.BattleCheckTime = SysTime() + GetConVar("cl_tim_battle_check_interval"):GetFloat()

      local ents_table = ents.GetAll()
      -- local ents_table = ents.FindByClass("*npc*")
      -- or just *n* or *_* (moNster_, Npc_)

      local e = LocalPlayer()
      local los = GetConVar("cl_tim_battle_los_required"):GetBool()
      local tagged_any = false
      local seen = {}
      local seen_total = 0
      for i = 1, #ents_table do
        local ent = ents_table[i]
        -- if SERVER then
          -- e = ( ent.GetEnemy and ent:GetEnemy() )
        -- end
        if
          IsValid(ent) and ent:IsNPC() and
          TypeID(e) == TYPE_ENTITY and
          IsValid(e) and e.IsPlayer and e:IsPlayer() and
          ((e.Health and e:Health() > 0) or (e.Alive and e:Alive())) and
          ((los and ent:IsLineOfSightClear( e )) or not los) then
            seen[ent:GetClass()] = (seen[ent:GetClass()] or 0) + 1
            seen_total = seen_total + 1
            for j = 1, #self.NPCClassTags do
              local class_tag = self.NPCClassTags[j]
              for k = 1, #class_tag[2] do
                if ent:GetClass():find( class_tag[2][k] ) then
                  self.State.combat_tags[class_tag[1]] = true
                  tagged_any = true
                  goto breakout
                end
              end
            end
            ::breakout::
        end
      end

      if seen_total > 0 then
        local printo = {seen_total, "witnesses, list: "}
        for classname, seen_count in pairs(seen) do
          table.insert(printo, seen_count)
          table.insert(printo, classname)
        end
        print(unpack(printo))
      end

      if tagged_any then
        self.State.in_combat = true
        self.State.combat_start_time = SysTime()
      end

      if self.PreviousState ~= nil and (not self.PreviousState.in_combat) and self.State.in_combat then
        self:SendEvent("combat_start", self.State)
      end

      if self.State.in_combat and (SysTime() > (self.State.combat_start_time + GetConVar("cl_tim_battle_decay_time"):GetFloat())) then
        self.State.combat_tags = {}
        self.State.in_combat = false
        self.State.combat_start_time = math.huge
        self:SendEvent("combat_end", self.State)
      end
    end



    self.PreviousState = self.State
    /*
      if ( TimelyMusic.current_track and TimelyMusic.current_track:IsPlaying() == false ) then
        TimelyMusic.current_track:Play()
        TimelyMusic.current_track:SetSoundLevel( 0 )
        TimelyMusic.current_track:SetDSP( 0 )
        if timelymusic_debug_check() then
          print("timelymusic: started playing current ambient track")
        end
      end
    */
  end,

  TrackClass = {
    new = function(self, filename, o)
      o = table.Merge({
        FileName = filename,

        InternalVolume = 0,
        TweenVolumeGoal = 0,
        TweenVolumeStart = 0,
        TweenVolumeBegin = math.huge,
        TweenVolumeDuration = 0,

        GoalStart = CurTime(),
        GoalDuration = 0,
        Sound = nil,
        SoundType = "IGModAudioChannel",
      }, o or {})
      setmetatable(o, self)
      self.__index = self
      if o.FileName then
        sound.PlayFile(o.FileName, "noplay noblock", function(sc, id, en)
          o:PlayFileCallback(sc, id, en)
        end)
      end
      return o
    end,

    Update = function(self)
      if self.Sound then
        if self.TweenVolumeBegin < CurTime() then
          self.InternalVolume = Lerp((CurTime() - self.TweenVolumeBegin) / self.TweenVolumeDuration, self.TweenVolumeStart, self.TweenVolumeGoal)
        end
        self.Sound:SetVolume(self.InternalVolume * GetConVar("cl_tim_volume"):GetFloat())
      end

      if self.DeleteAfter ~= nil and self.DeleteAfter < CurTime() then
        if self.Sound then
          self.Sound:Stop()
        end
        table.RemoveByValue(TimelyMusic.Tracks, self)
      end
    end,

    PlayFileCallback = function(self, soundchannel, errorID, errorName)
      if IsValid(soundchannel) then
        print("Sound channel loaded.")
        self.Sound = soundchannel
        self.Sound:EnableLooping(true)
        self.Sound:SetVolume(0)
        if self.PlayOnAwake then
          self:Play(TimelyMusic:GetCrossFadeDuration())
          TimelyMusic:MuteAllBut(self, TimelyMusic:GetCrossFadeDuration())
        end
        table.insert(TimelyMusic.Tracks, self)
      else
        print("Error loading sound!", errorID, errorName)
      end
    end,

    HasFeature = function(self, feature_name)
      return false
    end,

    GetMusicForCondition = function(self, event_name, event_data)
      return nil
    end,

    Play = function(self, fadetime)
      self.Sound:Play()
      -- self.Sound:SetPan(0)
      if (fadetime or 0) >= 0 then
        self.TweenVolumeGoal = 1
        self.TweenVolumeStart = 0
        self.TweenVolumeBegin = CurTime()
        self.TweenVolumeDuration = fadetime
      end
    end,
  },
  MusicThemeInterface = {
    new = function(self, o)
      o = o or {}
      setmetatable(o, self)
      self.__index = self
      return o
    end,

    HasFeature = function(self, feature_name)
      return false
    end,

    GetMusicForCondition = function(self, event_name, event_data)
      return nil
    end,
  },
}

if StormFox2 and StormFox2.Time and StormFox2.Time.GetSpeed then
  TimelyMusic.GetCrossFadeDuration = function()
    return (StormFox2.Time.GetSpeed_RAW and StormFox2.Time.GetSpeed_RAW() or (StormFox2.Time.GetSpeed() / 60)) * GetConVar("cl_tim_crossfade_time"):GetFloat()
    /*
    if StormFox2.Version <= 2.31 then
      return (StormFox2.Time.GetSpeed() / 60) * GetConVar("cl_tim_crossfade_time"):GetFloat()
    else
      return StormFox2.Time.GetSpeed() * GetConVar("cl_tim_crossfade_time"):GetFloat()
    end
    */
  end
end

if StormFox2 and StormFox2.Time and StormFox2.Time.Get then
  TimelyMusic.GetTime = StormFox2.Time.Get
end

function TimelyMusic.SaveThemes()
  if CLIENT then
    file.Write( "timely_music_enabled_themes.txt", util.TableToJSON( TimelyMusic.EnabledThemes ) )
  end
end

function TimelyMusic.LoadThemes()
  if CLIENT then
    if (file.Exists( "timely_music_enabled_themes.txt", "DATA" )) then
      TimelyMusic.EnabledThemes = util.JSONToTable( file.Read( "timely_music_enabled_themes.txt", "DATA" ) )
    else
      file.Write( "timely_music_enabled_themes.txt", util.TableToJSON( TimelyMusic.EnabledThemes ) )
    end
    TimelyMusic.RefreshListView()
  end
end

function TimelyMusic.RefreshListView()
  if TimelyMusic.ListView then
    TimelyMusic.ListView:Clear()

    for k, _ in SortedPairs(TimelyMusic.Themes) do
      local state = language.GetPhrase("inactive")
      if TimelyMusic.EnabledThemes[k] then
        state = language.GetPhrase("active")
      end
      TimelyMusic.ListView:AddLine( k, state )
    end
    TimelyMusic.ListView:GetDataHeight()
    TimelyMusic.ListView:SetTall(22 + math.min(TimelyMusic.ListView:DataLayout(), 160))
  end
end

if is_reload then hook.Remove( "Think", "TimelyMusic_Think") end
hook.Add( "Think", "TimelyMusic_Think", function()
  TimelyMusic:Think()
end)

local function initTimelyMusic()
  print("Initialized!")
end
local function reloadTimelyMusic()
  print("Reloaded!")
  RunConsoleCommand("stopsound")
  local files = file.Find( "timely_music/modules/*.lua", "lsv" )
  for _, mod in ipairs(files) do
    AddCSLuaFile( "timely_music/modules/" .. mod )
    include( "timely_music/modules/" .. mod )
  end
  TimelyMusic.BakeChains()
  TimelyMusic.AssembleTracks()
  TimelyMusic.LoadThemes()
end

concommand.Add("timelymusic_reload", reloadTimelyMusic, nil, language.GetPhrase("timelymusic.cl_tim_reload_timelymusic"))
concommand.Add("timelymusic_init", function()
  initTimelyMusic()
  reloadTimelyMusic()
end)

-- hook.Add( "InitPostEntity", "TimelyMusic_InitPostEntity", function() print("we are born") end )

-- @INIT/RELOAD
if not is_reload then
  initTimelyMusic()
  reloadTimelyMusic()
elseif is_reload then
  reloadTimelyMusic()
  TimelyMusic:Think()
  TimelyMusic:Think()
  TimelyMusic:SendEvent("initpostentity", TimelyMusic.State)
end

if StormFox2 then
  hook.Add( "StormFox2.InitPostEntity", "TimelyMusic_PostLoad", function()
    timer.Simple(2.2, function()
      join_time = SysTime()
      TimelyMusic:Think()
      TimelyMusic:Think()
      TimelyMusic:SendEvent("initpostentity", TimelyMusic.State)
    end)
    hook.Remove("StormFox2.InitPostEntity", "TimelyMusic_PostLoad")
  end)
else
  hook.Add( "InitPostEntity", "TimelyMusic_PostLoad", function()
    join_time = SysTime()
    TimelyMusic.LoadThemes()
    TimelyMusic:Think()
    TimelyMusic:Think()
    TimelyMusic:SendEvent("initpostentity", TimelyMusic.State)
    hook.Remove("InitPostEntity", "TimelyMusic_PostLoad")
  end )
end