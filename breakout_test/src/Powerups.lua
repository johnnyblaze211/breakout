Powerup = Class{}

function Powerup:init(x,y,type)
  self.x = x
  self.y = y
  self.width = 16
  self.height = 16
  self.type = type
  self.active = false
  self.remove = try

end


function Powerup:collides(target)
  if self.x > target.x + target.width or target.x > self.x + self.width then
      return false
  end

  if self.y > target.y + target.height or target.y > self.y + self.height then
      return false
  end

  return true
end

function Powerup:update(dt)
  self.y = self.y + dt * 20
  if self.y > VIRTUAL_HEIGHT then
    self.remove = true
  end
end

function Powerup:activate()
  self.active = true
  self.remove = true

end

function Powerup:render()
  love.graphics.draw(gTextures['main'],gFrames['powerups'][self.type],self.x,self.y)
end
