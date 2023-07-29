AddCSLuaFile()
if GetConVar("cl_tim_debug_enable"):GetBool() then
  print("TimelyMusic:", "tiny_talos loaded")
end
local tiny_talos = TimelyMusic.MusicThemeInterface:new({})
function tiny_talos:GetMusicForCondition(event_name, event_data)
  if not event_data.in_combat then
    time = event_data.time_hours
    if time > 06 and time < 10 then
      return "sound/timely_music/tiny_talos/dawn_dusk.wav"
    elseif time > 10 and time < 18 then
        return "sound/timely_music/tiny_talos/day.wav"
    elseif time > 18 and time < 22 then
      return "sound/timely_music/tiny_talos/dawn_dusk.wav"
    elseif time > 22 or time < 06 then
      return "sound/timely_music/tiny_talos/night.wav"
    end
  end
end
TimelyMusic.AddTheme("tiny_talos", tiny_talos)
