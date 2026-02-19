-- ============================================================
--  ✦ FLOAT — A Chill Physics Puzzle Game (LÖVR)
-- ============================================================
--  You are in a calm, misty void. Glowing orbs and shapes
--  drift around you. Your goal: stack & balance them on
--  pedestals to unlock the next level.
--
--  CONTROLS:
--    Hand tracking:
--      • Reach & pinch (thumb+index) to GRAB a nearby object
--      • Release pinch to DROP / place it
--      • Two-hand pinch same object → SCALE it
--
--    Controllers:
--      • Trigger         → grab nearest object
--      • Left Stick      → walk / strafe
--      • Right Stick X   → snap turn (30° steps)
--      • Right Stick Y   → adjust height (seated ↔ standing)
--      • A / X           → reset level
--      • B / Y           → next level (when solved)
--
--  TIP: On first load the world snaps to your position.
--       If the pedestal is unreachable, press A/X to recenter!
-- 
--  TODO: needs refactor, file way to long, scaling of items not working, dont need the X axis of right thumbstick, just the height, plus direction with left stick is inversed
-- ============================================================

-- ─── TINY VECTOR LIBRARY ────────────────────────────────────

local function vec3(x,y,z) return {x=x,y=y,z=z} end
local function vadd(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end
local function vsub(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
local function vscale(a,s) return vec3(a.x*s,a.y*s,a.z*s) end
local function vdot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end
local function vlen(a) return math.sqrt(vdot(a,a)) end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end

-- pastel HSL helper
local function hslColor(h)  -- h in 0..360
  h=h/60; local s=.55; local l=.72
  local c=(1-math.abs(2*l-1))*s
  local x2=c*(1-math.abs(h%2-1))
  local r2,g2,b2=0,0,0
  if h<1     then r2,g2,b2=c,x2,0
  elseif h<2 then r2,g2,b2=x2,c,0
  elseif h<3 then r2,g2,b2=0,c,x2
  elseif h<4 then r2,g2,b2=0,x2,c
  elseif h<5 then r2,g2,b2=x2,0,c
  else            r2,g2,b2=c,0,x2 end
  local m=l-.5*c
  return {r2+m,g2+m,b2+m,1}
end

-- ─── WORLD STATE ────────────────────────────────────────────

local GRAVITY  = -2.2
local DAMPING  = 0.983
local FLOOR_Y  = 0.0

local objects  = {}
local pedestal = {}
local level    = 1
local solved   = false
local solvedTimer = 0
local ambient  = {}
local t        = 0   -- global time

-- Smoothed HUD position (lerped each frame to reduce jitter)
local hudPos     = {x=0, y=1.4, z=-1.3}

-- Grab state  (1=left, 2=right)
local grabbed    = {[1]=nil, [2]=nil}
local grabOffset = {[1]=vec3(0,0,0), [2]=vec3(0,0,0)}
local GRAB_DIST  = 0.28
local PINCH_TH   = 0.035

-- ─── LOCOMOTION ─────────────────────────────────────────────
-- We move the WORLD relative to the player (headset pos is read-only)
-- worldX/Z = world origin offset; worldYaw = accumulated snap-turn angle
local worldX   = 0
local worldY   = 0   -- vertical offset for seated/standing adjust
local worldZ   = 0
local worldYaw = 0   -- radians, snap-turned

local MOVE_SPEED   = 1.4   -- m/s
local SNAP_ANGLE   = math.pi / 6  -- 30° per snap turn
local snapCooldown = {[1]=0,[2]=0} -- prevent repeated snaps
local SNAP_CD      = 0.3

-- helpers: transform a world-space point into player-relative space
local function toWorld(lx,ly,lz)
  -- rotate by worldYaw then translate by worldX/Z
  local c=math.cos(worldYaw); local s=math.sin(worldYaw)
  local rx = c*lx - s*lz
  local rz = s*lx + c*lz
  return rx+worldX, ly+worldY, rz+worldZ
end
local function fromWorld(wx,wy,wz)
  local dx=wx-worldX; local dz=wz-worldZ; local dy=wy-worldY
  local c=math.cos(-worldYaw); local s=math.sin(-worldYaw)
  return c*dx-s*dz, dy, s*dx+c*dz
end



local LEVELS = {
  { orbs=3, pedestalR=0.38, spread=0.9, grav=-2.2, label="Balance"  },
  { orbs=5, pedestalR=0.26, spread=1.1, grav=-1.9, label="Patience" },
  { orbs=7, pedestalR=0.20, spread=1.3, grav=-1.4, label="Zen"      },
}

-- ─── OBJECT FACTORY ─────────────────────────────────────────

local function newBody(x,y,z,r,kind,col)
  return {
    pos   = vec3(x,y,z),
    vel   = vec3((math.random()-.5)*.08, 0, (math.random()-.5)*.08),
    r     = r,
    kind  = kind,          -- 'sphere' | 'cube'
    color = col,
    mass  = r*r*4,
    held  = false,
    onPed = false,
    angle = math.random()*math.pi*2,
    spin  = (math.random()-.5)*.4,
  }
end

-- ─── LOAD LEVEL ─────────────────────────────────────────────

local function loadLevel(n)
  local def = LEVELS[n] or LEVELS[#LEVELS]
  objects     = {}
  solved      = false
  solvedTimer = 0
  grabbed     = {[1]=nil,[2]=nil}
  GRAVITY     = def.grav

  -- Snap world so player is at local origin, standing height calibrated
  local hx,hy,hz = lovr.headset.getPosition()
  worldX   = hx
  worldY   = hy - 1.4   -- assume avg eye height 1.4m; floor = 0 in local space
  worldZ   = hz
  worldYaw = 0

  -- Pedestal sits 0.8m in front in local space, just above local floor
  pedestal = {
    pos = vec3(0, FLOOR_Y+0.05, -0.8),
    r   = def.pedestalR,
    h   = 0.07,
  }

  local kinds = {'sphere','cube'}
  for i=1,def.orbs do
    local ang  = (i/def.orbs)*math.pi*2
    local x    = math.cos(ang)*def.spread*.65
    local y    = 1.3 + math.random()*.5   -- float at comfortable reach height
    local z    = math.sin(ang)*def.spread*.35 - 0.4
    local r    = 0.07 + math.random()*.055
    local kind = kinds[math.random(2)]
    local col  = hslColor((i/def.orbs)*340 + 10)
    table.insert(objects, newBody(x,y,z,r,kind,col))
  end

  -- decorative background drifters
  ambient = {}
  for i=1,22 do
    table.insert(ambient,{
      x=(math.random()-.5)*9,
      y=math.random()*3.5+.3,
      z=(math.random()-.5)*9,
      r=math.random()*.035+.008,
      spd=math.random()*.005+.001,
      phase=math.random()*math.pi*2,
      col={math.random()*.3+.45,math.random()*.3+.55,1,.28},
    })
  end
end

-- ─── PHYSICS HELPERS ────────────────────────────────────────

local function resolveCollision(a,b)
  if a.held and b.held then return end
  local d   = vsub(b.pos,a.pos)
  local len = vlen(d)
  local mn  = a.r+b.r
  if len>=mn or len<1e-6 then return end
  local n   = vscale(d,1/len)
  local pen = mn-len
  local ta  = a.held and 0 or b.mass/(a.mass+b.mass)
  local tb  = b.held and 0 or a.mass/(a.mass+b.mass)
  a.pos = vsub(a.pos,vscale(n,pen*ta))
  b.pos = vadd(b.pos,vscale(n,pen*tb))
  local rv  = vsub(b.vel,a.vel)
  local sep = vdot(rv,n)
  if sep>=0 then return end
  local j = -1.25*sep/(1/a.mass+1/b.mass)
  if not a.held then a.vel=vsub(a.vel,vscale(n,j/a.mass)) end
  if not b.held then b.vel=vadd(b.vel,vscale(n,j/b.mass)) end
end

local function pedestalCollide(o)
  local topY=pedestal.pos.y+pedestal.h
  local dx=o.pos.x-pedestal.pos.x
  local dz=o.pos.z-pedestal.pos.z
  local flat=math.sqrt(dx*dx+dz*dz)
  if flat < pedestal.r+o.r*.5 and o.pos.y-o.r < topY and o.pos.y > pedestal.pos.y-o.r then
    o.pos.y=topY+o.r
    o.vel.y=math.abs(o.vel.y)*.18
    o.vel.x=o.vel.x*.55
    o.vel.z=o.vel.z*.55
  end
end

local function checkOnPedestal(o)
  local topY=pedestal.pos.y+pedestal.h
  local dx=o.pos.x-pedestal.pos.x
  local dz=o.pos.z-pedestal.pos.z
  local flat=math.sqrt(dx*dx+dz*dz)
  return flat < pedestal.r+o.r*.4
     and math.abs(o.pos.y-o.r-topY) < 0.14
     and math.abs(o.vel.y) < 0.08
end

-- ─── HAND / CONTROLLER HELPERS ──────────────────────────────

local function getHandPos(side)
  local sk=lovr.headset.getSkeleton(side)
  if sk then
    local j=sk[10]  -- index tip = joint 10 (1-based)
    if j and j[1] then
      local lx,ly,lz = fromWorld(j[1],j[2],j[3])
      return vec3(lx,ly,lz),true
    end
  end
  local x,y,z=lovr.headset.getPosition(side)
  if x then
    local lx,ly,lz = fromWorld(x,y,z)
    return vec3(lx,ly,lz),false
  end
  return nil,false
end

local function handPinching(side)
  local sk=lovr.headset.getSkeleton(side)
  if not sk then return false end
  local ji=sk[10]  -- index tip
  local jt=sk[5]   -- thumb tip
  if not(ji and jt and ji[1] and jt[1]) then return false end
  local dx=ji[1]-jt[1]; local dy=ji[2]-jt[2]; local dz=ji[3]-jt[3]
  return math.sqrt(dx*dx+dy*dy+dz*dz)<PINCH_TH
end

local function nearestFree(pos)
  local best,bestD=nil,GRAB_DIST
  for _,o in ipairs(objects) do
    if not o.held then
      local d=vlen(vsub(o.pos,pos))
      if d<bestD then best=o;bestD=d end
    end
  end
  return best
end

-- ─── LOVR CALLBACKS ─────────────────────────────────────────

function lovr.load()
  math.randomseed(os.time())
  loadLevel(1)
end

function lovr.update(dt)
  t=t+dt

  -- ── Smooth HUD position (follows head lazily) ────────────
  do
    local hx,hy,hz    = lovr.headset.getPosition()
    local ox,oy,oz,ow = lovr.headset.getOrientation()
    -- forward vector from quat
    local fx = 2*(ox*oz + ow*oy)
    local fy = 2*(oy*oz - ow*ox)
    local fz = 1 - 2*(ox*ox + oy*oy)
    -- flatten to horizontal only (ignore pitch) so HUD stays level
    local flen = math.sqrt(fx*fx + fz*fz)
    if flen > 0.01 then fx=fx/flen; fz=fz/flen end
    fy = 0  -- keep HUD at fixed height
    local hd = 1.2
    local tx = hx + fx*hd
    local ty = hy - 0.18     -- slightly below eye level
    local tz = hz + fz*hd
    -- lazy lerp so HUD drifts into view rather than snapping/jittering
    local s = math.min(1, 2.5 * dt)  -- smooth speed, dt-based
    hudPos.x = hudPos.x + (tx - hudPos.x) * s
    hudPos.y = hudPos.y + (ty - hudPos.y) * s
    hudPos.z = hudPos.z + (tz - hudPos.z) * s
  end

  -- ── Locomotion (left stick = walk, right stick = snap turn) ─
  do
    local hox,hoy,hoz,how = lovr.headset.getOrientation()
    -- head yaw only (flatten pitch/roll)
    local headYaw = math.atan2(
      2*(hoy*how + hox*hoz),
      1 - 2*(hoy*hoy + hox*hox)
    )
    -- combine head yaw with world yaw for movement direction
    local moveYaw = headYaw + worldYaw

    -- Left stick → translate world origin opposite direction (= player moves forward)
    local lx,ly = lovr.headset.getAxis('left','thumbstick')
    if lx and ly and not grabbed[1] then
      local c=math.cos(moveYaw); local s=math.sin(moveYaw)
      local mx = (s*ly + c*lx) * MOVE_SPEED * dt
      local mz = (c*ly - s*lx) * MOVE_SPEED * dt
      worldX = worldX + mx
      worldZ = worldZ + mz
    end

    -- Right stick X → snap turn
    local rx,ry = lovr.headset.getAxis('right','thumbstick')
    if rx and math.abs(rx) > 0.6 then
      snapCooldown[2] = snapCooldown[2] - dt
      if snapCooldown[2] <= 0 then
        worldYaw = worldYaw + (rx > 0 and -SNAP_ANGLE or SNAP_ANGLE)
        snapCooldown[2] = SNAP_CD
      end
    else
      snapCooldown[2] = 0
    end

    -- Right stick Y → vertical offset (seated/standing calibration)
    if ry and math.abs(ry) > 0.5 then
      worldY = worldY + ry * 0.5 * dt
    end
  end


  for idx,side in ipairs({'left','right'}) do
    local hpos,isHand = getHandPos(side)
    if not hpos then goto skip end

    local wantGrab = isHand and handPinching(side)
                             or lovr.headset.isDown(side,'trigger')

    if wantGrab then
      if not grabbed[idx] then
        local o=nearestFree(hpos)
        if o then
          grabbed[idx]=o; o.held=true
          grabOffset[idx]=vsub(o.pos,hpos)
        end
      else
        local o=grabbed[idx]
        -- smooth follow
        local target=vadd(hpos,grabOffset[idx])
        o.vel=vscale(vsub(target,o.pos),14)
        o.pos=vadd(o.pos,vscale(o.vel,dt))
        o.vel=vscale(o.vel,.25)
        -- controller extras
        if not isHand then
          local tx,ty=lovr.headset.getAxis(side,'thumbstick')
          if tx and ty then
            o.angle=o.angle+tx*dt*2.5
            grabOffset[idx].z=clamp(grabOffset[idx].z-ty*dt*.55,-1.6,-.05)
          end
        end
      end
    else
      if grabbed[idx] then grabbed[idx].held=false; grabbed[idx]=nil end
    end

    -- Two-hand scale same object
    if grabbed[1] and grabbed[2] and grabbed[1]==grabbed[2] then
      local p1=getHandPos('left'); local p2=getHandPos('right')
      if p1 and p2 then
        grabbed[1].r=clamp(vlen(vsub(p1,p2))*.42,.04,.24)
        grabbed[1].mass=grabbed[1].r*grabbed[1].r*4
      end
    end

    ::skip::
  end

  -- ── Buttons ─────────────────────────────────────────────
  for _,side in ipairs({'left','right'}) do
    if lovr.headset.wasPressed(side,'a') or lovr.headset.wasPressed(side,'x') then
      loadLevel(level)
    end
    if solved and (lovr.headset.wasPressed(side,'b') or lovr.headset.wasPressed(side,'y')) then
      level=math.min(level+1,#LEVELS); loadLevel(level)
    end
  end

  -- ── Physics ─────────────────────────────────────────────
  for _,o in ipairs(objects) do
    if not o.held then
      o.vel.y=o.vel.y+GRAVITY*dt
      o.vel=vscale(o.vel,DAMPING)
      o.pos=vadd(o.pos,vscale(o.vel,dt))
      -- floor
      if o.pos.y-o.r<FLOOR_Y then
        o.pos.y=FLOOR_Y+o.r
        o.vel.y=math.abs(o.vel.y)*.22
        o.vel.x=o.vel.x*.6; o.vel.z=o.vel.z*.6
      end
      -- boundary walls (soft)
      for _,ax in ipairs({'x','z'}) do
        if math.abs(o.pos[ax])>4.2 then
          o.vel[ax]=-o.vel[ax]*.5
          o.pos[ax]=clamp(o.pos[ax],-4.2,4.2)
        end
      end
      pedestalCollide(o)
    end
    o.angle=o.angle+o.spin*dt
    o.onPed=checkOnPedestal(o)
  end

  -- Object-object collisions
  for i=1,#objects do
    for j=i+1,#objects do resolveCollision(objects[i],objects[j]) end
  end

  -- Ambient
  for _,a in ipairs(ambient) do
    a.phase=a.phase+a.spd
    a.y=a.y+math.sin(a.phase*.4)*.0007
  end

  -- Win check
  if not solved then
    local cnt=0
    for _,o in ipairs(objects) do if o.onPed then cnt=cnt+1 end end
    if cnt==#objects then solved=true; solvedTimer=0 end
  else
    solvedTimer=solvedTimer+dt
  end
end

function lovr.draw(pass)

  -- ── Sky sphere (no world transform — always centered on player) ──
  pass:setCullMode('front')
  pass:setColor(.03,.04,.09,1)
  pass:sphere(0,1.6,0,28)
  pass:setCullMode('back')

  -- ── Apply world transform for all game geometry ────────────
  -- This shifts/rotates the entire game world relative to player
  pass:push()
  pass:translate(worldX, worldY, worldZ)
  pass:rotate(worldYaw, 0,1,0)

  -- ── Floor ──────────────────────────────────────────────
  pass:setColor(.10,.12,.20,.8)
  pass:push()
  pass:translate(0,FLOOR_Y,0)
  pass:rotate(-math.pi/2,1,0,0)
  pass:plane(0,0,0,12,12)
  pass:pop()

  -- subtle grid lines on floor
  pass:setColor(.18,.22,.35,.4)
  for i=-5,5 do
    pass:line(i,FLOOR_Y+.001,-6, i,FLOOR_Y+.001,6)
    pass:line(-6,FLOOR_Y+.001,i, 6,FLOOR_Y+.001,i)
  end

  -- ── Ambient drifters ───────────────────────────────────
  for _,a in ipairs(ambient) do
    local pulse=.8+math.sin(a.phase)*.2
    pass:setColor(a.col[1]*pulse,a.col[2]*pulse,a.col[3],a.col[4])
    pass:sphere(a.x,a.y+math.sin(a.phase)*.12,a.z,a.r)
  end

  -- ── Pedestal ───────────────────────────────────────────
  local pg = solved and (.55+math.sin(t*4)*.35) or 0
  pass:setColor(.45+pg*.25,.60+pg*.15,.85+pg*.1,1)
  -- pedestal disk
  pass:push()
  pass:translate(pedestal.pos.x, pedestal.pos.y, pedestal.pos.z)
  pass:rotate(math.pi/2, 1,0,0)
  pass:cylinder(0,0,0, pedestal.r, pedestal.h*2)
  pass:pop()

  -- glowing ring
  local ringA = .15+pg*.35
  pass:setColor(.5,.75,1,ringA)
  pass:push()
  pass:translate(pedestal.pos.x, pedestal.pos.y+pedestal.h, pedestal.pos.z)
  pass:torus(0,0,0, pedestal.r+.025, .012)
  pass:pop()

  -- pedestal column
  pass:setColor(.25,.30,.45,1)
  pass:push()
  pass:translate(pedestal.pos.x, pedestal.pos.y-0.25, pedestal.pos.z)
  pass:rotate(math.pi/2, 1,0,0)
  pass:cylinder(0,0,0, .04, .5)
  pass:pop()

  -- ── Physics objects ────────────────────────────────────
  for _,o in ipairs(objects) do
    local r,g,b=o.color[1],o.color[2],o.color[3]

    if o.onPed then
      local pulse=.7+math.sin(t*3+o.angle)*.3
      r=clamp(r*pulse+.12,0,1); g=clamp(g*pulse+.08,0,1)
    end
    if o.held then r=clamp(r+.18,0,1); g=clamp(g+.18,0,1); b=clamp(b+.18,0,1) end

    pass:setColor(r,g,b,1)

    if o.kind=='sphere' then
      pass:sphere(o.pos.x,o.pos.y,o.pos.z,o.r)
    else
      local s=o.r*1.65
      pass:push()
      pass:translate(o.pos.x,o.pos.y,o.pos.z)
      pass:rotate(o.angle,0,1,0)
      pass:box(0,0,0,s,s,s)
      pass:pop()
    end

    -- soft glow halo
    pass:setColor(r,g,b,.06)
    pass:sphere(o.pos.x,o.pos.y,o.pos.z,o.r*1.4)

    -- number label
    pass:setColor(1,1,1,.7)
  end
  pass:setColor(1,1,1,1)

  -- ── Hand skeleton (transform joints into local space) ──────
  for hidx,side in ipairs({'left','right'}) do
    local sk=lovr.headset.getSkeleton(side)
    if sk then
      for j=1,#sk do
        local joint=sk[j]
        if joint and joint[1] then
          local lx,ly,lz = fromWorld(joint[1],joint[2],joint[3])
          if hidx==1 then pass:setColor(.45,.85,1,.7)
          else             pass:setColor(1,.65,.9,.7) end
          pass:sphere(lx,ly,lz, joint[4] or .004)
        end
      end
    end

    -- controller ray (also in local space)
    if not lovr.headset.getSkeleton(side) then
      local x,y,z=lovr.headset.getPosition(side)
      if x then
        local lx,ly,lz=fromWorld(x,y,z)
        local ox,oy,oz,ow=lovr.headset.getOrientation(side)
        local fx=2*(ox*oz+ow*oy)
        local fy=2*(oy*oz-ow*ox)
        local fz=1-2*(ox*ox+oy*oy)
        pass:setColor(.8,.85,1,.35)
        pass:line(lx,ly,lz, lx+fx*.9,ly+fy*.9,lz+fz*.9)
      end
    end
  end
  pass:setColor(1,1,1,1)

  -- ── End world transform ─────────────────────────────────
  pass:pop()

  -- ── Gaze-locked HUD (billboarded, smoothed) ────────────
  local onCnt=0
  for _,o in ipairs(objects) do if o.onPed then onCnt=onCnt+1 end end
  local def=LEVELS[level] or LEVELS[#LEVELS]

  -- billboard: face HUD toward player head
  local hx,hy,hz = lovr.headset.getPosition()
  local dx = hx - hudPos.x
  local dz = hz - hudPos.z
  local yaw = math.atan2(dx, dz)  -- angle to face player

  pass:push()
  pass:translate(hudPos.x, hudPos.y, hudPos.z)
  pass:rotate(yaw, 0,1,0)  -- spin on Y axis to face player

  -- background panel
  pass:setColor(0.04, 0.06, 0.14, 0.82)
  pass:plane(0, 0, 0, 0.55, 0.26)

  -- border
  pass:setColor(0.3, 0.5, 0.9, 0.5)
  pass:plane(0, 0, -0.001, 0.57, 0.28)
  pass:setColor(0.04, 0.06, 0.14, 0.82)
  pass:plane(0, 0, -0.0005, 0.55, 0.26)

  -- title
  pass:setColor(0.75, 0.92, 1, 1)
  pass:text(string.format("✦ FLOAT  ·  Level %d: %s", level, def.label),
    0, 0.088, 0, 0.021)

  -- progress bar background
  pass:setColor(0.12, 0.15, 0.25, 1)
  pass:plane(0, 0.048, 0.001, 0.36, 0.013)
  -- progress bar fill
  local frac = onCnt / math.max(#objects, 1)
  if frac > 0 then
    pass:setColor(0.3, 1, 0.65, 1)
    pass:plane(-0.18 + 0.18*frac, 0.048, 0.002, 0.36*frac, 0.013)
  end

  -- orb count
  pass:setColor(0.85, 1, 0.88, 1)
  pass:text(string.format("Orbs on pedestal: %d / %d", onCnt, #objects),
    0, 0.025, 0, 0.017)

  -- controls hint
  pass:setColor(0.5, 0.52, 0.65, 1)
  pass:text("Grab: Pinch/Trigger  Move: L-Stick  Turn: R-Stick  Height: R-Stick Y",
    0, -0.01, 0, 0.011)

  -- status line
  if solved then
    local pulse = 0.6 + math.sin(t*5)*0.4
    pass:setColor(pulse, 1, pulse*0.75, 1)
    pass:text(string.format("✓ CLEARED!  Press B/Y for next level  (%.0fs)", solvedTimer),
      0, -0.048, 0, 0.019)
  else
    pass:setColor(0.42, 0.45, 0.6, 1)
    pass:text("Balance all orbs on the glowing pedestal",
      0, -0.048, 0, 0.013)
  end

  pass:setColor(1,1,1,1)
  pass:pop()

  pass:setColor(1,1,1,1)
end