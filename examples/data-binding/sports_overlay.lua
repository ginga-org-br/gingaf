local function randomStats()
  local homePoss = math.random(40, 65)
  local awayPoss = 100 - homePoss
  return {
    {
      metric = "Ball Speed",
      value = string.format("%.1f km/h", 95.0 + math.random(0, 300) / 10.0)
    },
    {
      metric = "Sprint Top Speed",
      value = string.format("%.1f km/h", 28.0 + math.random(0, 80) / 10.0)
    },
    {
      metric = "Possession",
      value = string.format("%d%% - %d%%", homePoss, awayPoss)
    },
    {
      metric = "Expected Goals (xG)",
      value = string.format("%.2f - %.2f", math.random(50, 350) / 100.0, math.random(20, 250) / 100.0)
    },
    {
      metric = "Pass Completion",
      value = string.format("%.1f%%", 75.0 + math.random(0, 200) / 10.0)
    }
  }
end

local data = {
  stats = randomStats(),
  cameras = {
    {
      name = "Cam 1: Tactical High",
      preview = "cam1.png",
      video = "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"
    },
    {
      name = "Cam 2: SpiderCam 360",
      preview = "cam2.png",
      video = "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"
    },
    {
      name = "Cam 3: Goal Line South",
      preview = "cam3.png",
      video = "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"
    },
    {
      name = "Cam 4: Bench & Coach",
      preview = "cam4.png",
      video = "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"
    }
  },
  video = {
    "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
    "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4",
    "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
    "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"
  }
}

function onTick(clockMs)
  data.stats = randomStats()
  return data
end

return data

