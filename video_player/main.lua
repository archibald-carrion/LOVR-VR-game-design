local totalFrames = 6700
local fps = 30

local texture
local material
local audio

function lovr.load()

  texture = lovr.graphics.newTexture(1024, 1024, {
    format = 'rgba8',
    usage = { 'sample', 'transfer' }
  })

  material = lovr.graphics.newMaterial({
    texture = texture,
    lighting = false
  })

  -- Correct 0.18 audio
  audio = lovr.audio.newSource("audio.ogg")
  audio:setLooping(true)
  audio:play()
end



function lovr.update(dt)

  -- Get playback time
  local time = audio:tell("seconds")

  -- Calculate frame from audio time
  local currentFrame = math.floor(time * fps) + 1

  if currentFrame > totalFrames then
    currentFrame = 1
    audio:seek(0)
  end

  local filename = string.format("frames/frame_%05d.jpg", currentFrame)

  local success, image = pcall(lovr.data.newImage, filename)

  if success and image then
    texture:setPixels(image)
  end
end

function lovr.draw(pass)
  pass:setCullMode('front')
  pass:setMaterial(material)
  pass:sphere(0, 1.6, 0, 50, 32, 0, math.pi)
end
