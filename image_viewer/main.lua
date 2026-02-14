local texture
local material

function lovr.load()
  texture = lovr.graphics.newTexture(
    "M3_Sky_Dome_equirectangular-jpg_clear_blue_sky_bright_1478788763_455173.jpg",
    { mipmaps = true }
  )

  material = lovr.graphics.newMaterial({
    texture = texture
  })
end

function lovr.draw(pass)
  pass:setCullMode('front')
  pass:setMaterial(material)
  pass:sphere(0, 1.6, 0, 50)
end
