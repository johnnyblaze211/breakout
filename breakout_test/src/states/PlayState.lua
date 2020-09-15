--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball0 = params.ball
    self.Balls = {}
    self.level = params.level
    self.inplayflag = true

    self.recoverPoints = 5000

    -- give ball random starting velocity
    self.ball0.dx = math.random(-200, 200)
    self.ball0.dy = math.random(-50, -60)
    table.insert(self.Balls, self.ball0)
    self.Powerups = {}
    self.timer = 0
    self.globaltimer = 0
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.timer = self.timer + dt
    self.globaltimer = self.globaltimer + dt
    if self.timer > 15 then
      table.insert(self.Powerups,Powerup(math.random(VIRTUAL_WIDTH - 16), -16, 9))
      self.timer = 0
    end

    self.paddle:update(dt)

    for k, powerup in pairs(self.Powerups) do
      powerup:update(dt)
      if powerup.active then
        if powerup.type == 9 then
          local ball1 = Ball()
          ball1.skin = self.ball0.skin
          ball1.x = self.paddle.x + self.paddle.width/2 - self.ball0.width/2
          ball1.y = self.paddle.y - self.ball0.height
          ball1.dx = math.random(0,200)
          ball1.dy = math.random(-50,-60)
          table.insert(self.Balls, ball1)

          local ball2 = Ball()
          ball2.skin = self.ball0.skin
          ball2.x = self.paddle.x + self.paddle.width/2 - self.ball0.width/2
          ball2.y = self.paddle.y - self.ball0.height
          ball2.dx = math.random(-200,0)
          ball2.dy = math.random(-50,-60)
          table.insert(self.Balls, ball2)
        end

        if powerup.type == 10 then
          local ball1 = Ball()
          ball1.skin = 7
          ball1.key = true
          ball1.x = self.paddle.x + self.paddle.width/2 - self.ball0.width/2
          ball1.y = self.paddle.y - self.ball0.height
          ball1.dx = math.random(0,200)
          ball1.dy = math.random(-50,-60)
          table.insert(self.Balls, ball1)
        end
      end

          --table.insert(self.balls, Ball(self.ball.skin, self.paddle.x + self.paddle.width/2 - self.ball.width/2, self.paddle.y - self.ball.height, math.random(-200,200), math.random(-50,-60)))

    end

    for k, ball in pairs(self.Balls) do
      ball:update(dt)

      if ball:collides(self.paddle) then
          -- raise ball above paddle in case it goes below it, then reverse dy
          ball.y = self.paddle.y - 8
          ball.dy = -ball.dy

          --
          -- tweak angle of bounce based on where it hits the paddle
          --

          -- if we hit the paddle on its left side while moving left...
          if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
              ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))

          -- else if we hit the paddle on its right side while moving right...
          elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
              ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
          end

          gSounds['paddle-hit']:play()
      end

    -- detect collision across all bricks with the ball


      for k, brick in pairs(self.bricks) do

          -- only check collision if we're in play
          if brick.inPlay and ball:collides(brick) then

              if brick.color == 1 and not brick.locked then
                if not(math.random(0,2) == 1) then
                  table.insert(self.Powerups, Powerup(brick.x + brick.width - 8, brick.y + brick.height/2, 9))
                  self.timer = 0
                end
              end
              -- add to score
              if not brick.locked then
                self.score = self.score + (brick.tier * 200 + brick.color * 25)
              else
                if ball.key then
                  self.score = self.score + 50000
                end
              end

              -- trigger the brick's hit function, which removes it from play
              if brick.locked then
                if ball.key then
                  brick:hit()
                end
              else
                brick:hit()
              end

              -- if we have enough points, recover a point of health
              if self.score > self.recoverPoints then
                  -- can't go above 3 health
                  self.health = math.min(3, self.health + 1)

                  -- multiply recover points by 2
                  self.recoverPoints = math.min(self.recoverPoints + 100000, self.recoverPoints * 2)
                  if not (self.paddle.size == 4) then
                      local size = self.paddle.size
                      local skin = self.paddle.skin
                      local x = self.paddle.x
                      self.paddle = Paddle(skin,size)
                      self.paddle.x = math.max(x - 16, 0)
                  end

                  -- play recover sound effect
                  gSounds['recover']:play()
              end

              -- go to our victory screen if there are no more bricks left
              if self:checkVictory() then
                  gSounds['victory']:play()

                  gStateMachine:change('victory', {
                      level = self.level,
                      paddle = self.paddle,
                      health = self.health,
                      score = self.score,
                      highScores = self.highScores,
                      ball = self.Balls[1],
                      recoverPoints = self.recoverPoints
                  })
              end

              --
              -- collision code for bricks
              --
              -- we check to see if the opposite side of our velocity is outside of the brick;
              -- if it is, we trigger a collision on that side. else we're within the X + width of
              -- the brick and should check to see if the top or bottom edge is outside of the brick,
              -- colliding on the top or bottom accordingly
              --

              -- left edge; only check if we're moving right, and offset the check by a couple of pixels
              -- so that flush corner hits register as Y flips, not X flips
              if ball.x + 2 < brick.x and ball.dx > 0 then

                  -- flip x velocity and reset position outside of brick
                  ball.dx = -ball.dx
                  ball.x = brick.x - 8

              -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
              -- so that flush corner hits register as Y flips, not X flips
              elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then

                  -- flip x velocity and reset position outside of brick
                  ball.dx = -ball.dx
                  ball.x = brick.x + 32

              -- top edge if no X collisions, always check
              elseif ball.y < brick.y then

                  -- flip y velocity and reset position outside of brick
                  ball.dy = -ball.dy
                  ball.y = brick.y - 8

              -- bottom edge if no X collisions or top collision, last possibility
              else

                  -- flip y velocity and reset position outside of brick
                  ball.dy = -ball.dy
                  ball.y = brick.y + 16
              end

              -- slightly scale the y velocity to speed up the game, capping at +- 150
              if math.abs(ball.dy) < 150 then
                  ball.dy = ball.dy * 1.02
              end

              -- only allow colliding with one brick, for corners
              break
          end
      end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    for k,powerup in pairs(self.Powerups) do
      if powerup.remove then
        table.remove(self.Powerups,k)
      elseif powerup:collides(self.paddle) then
        powerup:activate()
        --table.remove(self.Powerups,k)
      end
    end

    self.inplayflag = false
    for k, ball in pairs(self.Balls) do
      if ball.remove == false then
        self.inplayflag = true
      end
    end
    for k, ball in pairs(self.Balls) do
      if ball.remove then
          table.remove(self.Balls, k)
      end
    end

    --[[if self.globaltimer > 3 then
      print(self.paddle.size)
      self.globaltimer = 0
    end]]

    if self.inplayflag == false then
      if not (self.paddle.size == 1) then
        local skin = self.paddle.skin
        local size = self.paddle.size
        self.paddle = Paddle(skin,size)
      end
      self.health = self.health - 1
      gSounds['hurt']:play()

      if self.health == 0 then
          gStateMachine:change('game-over', {
              score = self.score,
              highScores = self.highScores
          })
      else
          gStateMachine:change('serve', {
              paddle = self.paddle,
              bricks = self.bricks,
              health = self.health,
              score = self.score,
              highScores = self.highScores,
              level = self.level,
              recoverPoints = self.recoverPoints
          })
      end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, powerup in pairs(self.Powerups) do
      powerup:render()
    end
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    for k, ball in pairs(self.Balls) do
      ball:render()
    end
    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end
    end

    return true
end
