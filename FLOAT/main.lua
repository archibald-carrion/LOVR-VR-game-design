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
--      • Right Stick Y   → adjust height (seated ↔ standing)
--      • A / X           → reset level
--      • B / Y           → next level (when solved)
--
--  TIP: On first load the world snaps to your position.
--       If the pedestal is unreachable, press A/X to recenter!
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

-- Two-hand scale state
local scaleState = nil  -- {obj, initDist, initR}

-- ─── LOCOMOTION ─────────────────────────────────────────────
local worldX   = 0
local worldY   = 0
local worldZ   = 0
local worldYaw = 0

local MOVE_SPEED   = 1.4
local SNAP_ANGLE   = math.pi / 6
local snapCooldown = {[1]=0,[2]=0}
local SNAP_CD      = 0.3

local function toWorld(lx,ly,lz)
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
    kind  = kind,
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
  scaleState  = nil
  GRAVITY     = def.grav

  local hx,hy,hz = lovr.headset.getPosition()
  worldX   = hx
  worldY   = hy - 1.4
  worldZ   = hz
  worldYaw = 0

  pedestal = {
    pos = vec3(0, FLOOR_Y+0.05, -0.8),
    r   = def.pedestalR,
    h   = 0.07,
  }

  local kinds = {'sphere','cube'}
  for i=1,def.orbs do
    local ang  = (i/def.orbs)*math.pi*2
    local x    = math.cos(ang)*def.spread*.65
    local y    = 1.3 + math.random()*.5
    local z    = math.sin(ang)*def.spread*.35 - 0.4
    local r    = 0.07 + math.random()*.055
    local kind = kinds[math.random(2)]
    local col  = hslColor((i/def.orbs)*340 + 10)
    table.insert(objects, newBody(x,y,z,r,kind,col))
  end

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
    local j=sk[10]
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
  local ji=sk[10]
  local jt=sk[5]
  if not(ji and jt and ji[1] and jt[1]) then return false end
  local dx=ji[1]-jt[1]; local dy=ji[2]-jt[2]; local dz=ji[3]-jt[3]
  return math.sqrt(dx*dx+dy*dy+dz*dz)<PINCH_TH
end

-- Returns the nearest object, including already-held ones (for second hand grab)
local function nearestObject(pos, excludeHeldBy)
  local best, bestD = nil, GRAB_DIST
  for _, o in ipairs(objects) do
    -- Skip if held by the *other* hand we're trying to exclude, unless scaling
    if not o.held or (excludeHeldBy and grabbed[excludeHeldBy] == o) then
      -- allow grabbing an already-held object with the second hand
    end
    local d = vlen(vsub(o.pos, pos))
    if d < bestD then best = o; bestD = d end
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

  -- ── Smooth HUD position ──────────────────────────────────
  do
    local hx,hy,hz    = lovr.headset.getPosition()
    local ox,oy,oz,ow = lovr.headset.getOrientation()
    local fx = 2*(ox*oz + ow*oy)
    local fz = 1 - 2*(ox*ox + oy*oy)
    local flen = math.sqrt(fx*fx + fz*fz)
    if flen > 0.01 then fx=fx/flen; fz=fz/flen end
    local hd = 1.2
    local tx = hx + fx*hd
    local ty = hy - 0.18
    local tz = hz + fz*hd
    local s = math.min(1, 2.5 * dt)
    hudPos.x = hudPos.x + (tx - hudPos.x) * s
    hudPos.y = hudPos.y + (ty - hudPos.y) * s
    hudPos.z = hudPos.z + (tz - hudPos.z) * s
  end

  -- ── Locomotion ───────────────────────────────────────────
  do
    local hox,hoy,hoz,how = lovr.headset.getOrientation()
    local headYaw = math.atan2(
      2*(hoy*how + hox*hoz),
      1 - 2*(hoy*hoy + hox*hox)
    )
    local moveYaw = headYaw + worldYaw

    -- Left stick → walk (direction corrected: forward = negative Z in local space)
    local lx,ly = lovr.headset.getAxis('left','thumbstick')
    if lx and ly and not grabbed[1] then
      local c=math.cos(moveYaw); local s=math.sin(moveYaw)
      -- fixed: negate mx/mz so stick-forward moves player forward
      local mx = -(s*ly + c*lx) * MOVE_SPEED * dt
      local mz = -(c*ly - s*lx) * MOVE_SPEED * dt
      worldX = worldX + mx
      worldZ = worldZ + mz
    end

    -- Right stick Y → vertical offset only (removed snap turn on X)
    local rx,ry = lovr.headset.getAxis('right','thumbstick')
    if ry and math.abs(ry) > 0.5 then
      worldY = worldY + ry * 0.5 * dt
    end
  end

  -- ── Grab & scale logic ───────────────────────────────────
  local handPos = {}
  local wantGrab = {}
  local isHand = {}

  for idx, side in ipairs({'left','right'}) do
    handPos[idx], isHand[idx] = getHandPos(side)
    if handPos[idx] then
      wantGrab[idx] = isHand[idx] and handPinching(side)
                                   or lovr.headset.isDown(side,'trigger')
    else
      wantGrab[idx] = false
    end
  end

  -- Determine if both hands are pinching/triggering
  local bothActive = wantGrab[1] and wantGrab[2] and handPos[1] and handPos[2]

  -- Check if both hands could grab the *same* nearest object
  if bothActive and not scaleState then
    -- Find the closest object to each hand
    local function nearestAny(pos)
      local best, bestD = nil, GRAB_DIST * 2  -- wider search for second hand
      for _, o in ipairs(objects) do
        local d = vlen(vsub(o.pos, pos))
        if d < bestD then best = o; bestD = d end
      end
      return best
    end
    local o1 = nearestAny(handPos[1])
    local o2 = nearestAny(handPos[2])
    if o1 and o1 == o2 then
      -- Both hands targeting the same object → enter scale mode
      -- Release any existing single-hand grabs first
      if grabbed[1] then grabbed[1].held = false; grabbed[1] = nil end
      if grabbed[2] then grabbed[2].held = false; grabbed[2] = nil end
      o1.held = true
      local initDist = vlen(vsub(handPos[1], handPos[2]))
      scaleState = { obj = o1, initDist = initDist, initR = o1.r }
    end
  end

  -- If we're in scale mode, update scale or exit
  if scaleState then
    local o = scaleState.obj
    if bothActive then
      local dist = vlen(vsub(handPos[1], handPos[2]))
      if scaleState.initDist > 0.001 then
        local newR = clamp(scaleState.initR * (dist / scaleState.initDist), 0.04, 0.28)
        o.r    = newR
        o.mass = newR * newR * 4
      end
      -- Move object to midpoint of both hands
      local mid = vscale(vadd(handPos[1], handPos[2]), 0.5)
      local target = mid
      o.vel = vscale(vsub(target, o.pos), 14)
      o.pos = vadd(o.pos, vscale(o.vel, dt))
      o.vel = vscale(o.vel, 0.25)
    else
      -- One or both hands released → exit scale mode
      o.held = false
      scaleState = nil
    end
    -- Skip regular single-hand grab processing this frame
    goto skipGrab
  end

  -- Regular single-hand grab processing
  for idx, side in ipairs({'left','right'}) do
    if not handPos[idx] then goto skipHand end

    if wantGrab[idx] then
      if not grabbed[idx] then
        -- Only grab free objects
        local best, bestD = nil, GRAB_DIST
        for _, o in ipairs(objects) do
          if not o.held then
            local d = vlen(vsub(o.pos, handPos[idx]))
            if d < bestD then best = o; bestD = d end
          end
        end
        if best then
          grabbed[idx] = best
          best.held    = true
          grabOffset[idx] = vsub(best.pos, handPos[idx])
        end
      else
        local o = grabbed[idx]
        local target = vadd(handPos[idx], grabOffset[idx])
        o.vel = vscale(vsub(target, o.pos), 14)
        o.pos = vadd(o.pos, vscale(o.vel, dt))
        o.vel = vscale(o.vel, .25)
        -- Controller depth push/pull on right stick Y (only when grabbing)
        if not isHand[idx] then
          local tx, ty = lovr.headset.getAxis(side, 'thumbstick')
          if tx and ty then
            o.angle = o.angle + tx * dt * 2.5
            grabOffset[idx].z = clamp(grabOffset[idx].z - ty * dt * .55, -1.6, -.05)
          end
        end
      end
    else
      if grabbed[idx] then grabbed[idx].held = false; grabbed[idx] = nil end
    end

    ::skipHand::
  end

  ::skipGrab::

  -- ── Buttons ──────────────────────────────────────────────
  for _,side in ipairs({'left','right'}) do
    if lovr.headset.wasPressed(side,'a') or lovr.headset.wasPressed(side,'x') then
      loadLevel(level)
    end
    if solved and (lovr.headset.wasPressed(side,'b') or lovr.headset.wasPressed(side,'y')) then
      level=math.min(level+1,#LEVELS); loadLevel(level)
    end
  end

  -- ── Physics ──────────────────────────────────────────────
  for _,o in ipairs(objects) do
    if not o.held then
      o.vel.y=o.vel.y+GRAVITY*dt
      o.vel=vscale(o.vel,DAMPING)
      o.pos=vadd(o.pos,vscale(o.vel,dt))
      if o.pos.y-o.r<FLOOR_Y then
        o.pos.y=FLOOR_Y+o.r
        o.vel.y=math.abs(o.vel.y)*.22
        o.vel.x=o.vel.x*.6; o.vel.z=o.vel.z*.6
      end
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

  for i=1,#objects do
    for j=i+1,#objects do resolveCollision(objects[i],objects[j]) end
  end

  for _,a in ipairs(ambient) do
    a.phase=a.phase+a.spd
    a.y=a.y+math.sin(a.phase*.4)*.0007
  end

  if not solved then
    local cnt=0
    for _,o in ipairs(objects) do if o.onPed then cnt=cnt+1 end end
    if cnt==#objects then solved=true; solvedTimer=0 end
  else
    solvedTimer=solvedTimer+dt
  end
end

function lovr.draw(pass)

  pass:setCullMode('front')
  pass:setColor(.03,.04,.09,1)
  pass:sphere(0,1.6,0,28)
  pass:setCullMode('back')

  pass:push()
  pass:translate(worldX, worldY, worldZ)
  pass:rotate(worldYaw, 0,1,0)

  pass:setColor(.10,.12,.20,.8)
  pass:push()
  pass:translate(0,FLOOR_Y,0)
  pass:rotate(-math.pi/2,1,0,0)
  pass:plane(0,0,0,12,12)
  pass:pop()

  pass:setColor(.18,.22,.35,.4)
  for i=-5,5 do
    pass:line(i,FLOOR_Y+.001,-6, i,FLOOR_Y+.001,6)
    pass:line(-6,FLOOR_Y+.001,i, 6,FLOOR_Y+.001,i)
  end

  for _,a in ipairs(ambient) do
    local pulse=.8+math.sin(a.phase)*.2
    pass:setColor(a.col[1]*pulse,a.col[2]*pulse,a.col[3],a.col[4])
    pass:sphere(a.x,a.y+math.sin(a.phase)*.12,a.z,a.r)
  end

  local pg = solved and (.55+math.sin(t*4)*.35) or 0
  pass:setColor(.45+pg*.25,.60+pg*.15,.85+pg*.1,1)
  pass:push()
  pass:translate(pedestal.pos.x, pedestal.pos.y, pedestal.pos.z)
  pass:rotate(math.pi/2, 1,0,0)
  pass:cylinder(0,0,0, pedestal.r, pedestal.h*2)
  pass:pop()

  local ringA = .15+pg*.35
  pass:setColor(.5,.75,1,ringA)
  pass:push()
  pass:translate(pedestal.pos.x, pedestal.pos.y+pedestal.h, pedestal.pos.z)
  pass:torus(0,0,0, pedestal.r+.025, .012)
  pass:pop()

  pass:setColor(.25,.30,.45,1)
  pass:push()
  pass:translate(pedestal.pos.x, pedestal.pos.y-0.25, pedestal.pos.z)
  pass:rotate(math.pi/2, 1,0,0)
  pass:cylinder(0,0,0, .04, .5)
  pass:pop()

  for _,o in ipairs(objects) do
    local r,g,b=o.color[1],o.color[2],o.color[3]
    if o.onPed then
      local pulse=.7+math.sin(t*3+o.angle)*.3
      r=clamp(r*pulse+.12,0,1); g=clamp(g*pulse+.08,0,1)
    end
    -- highlight when scaling
    local isScaling = scaleState and scaleState.obj == o
    if o.held then r=clamp(r+.18,0,1); g=clamp(g+.18,0,1); b=clamp(b+.18,0,1) end
    if isScaling then r=clamp(r+.25,0,1); g=clamp(g+.10,0,1); b=clamp(b+.25,0,1) end

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

    pass:setColor(r,g,b,.06)
    pass:sphere(o.pos.x,o.pos.y,o.pos.z,o.r*1.4)

    -- scale indicator: draw a line between hands when scaling this object
    if isScaling and handPos and handPos[1] and handPos[2] then
      pass:setColor(1,1,0.5,0.5)
      pass:line(
        handPos[1].x, handPos[1].y, handPos[1].z,
        handPos[2].x, handPos[2].y, handPos[2].z
      )
    end

    pass:setColor(1,1,1,.7)
  end
  pass:setColor(1,1,1,1)

  -- Hand skeleton
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

  pass:pop()

  -- ── Gaze-locked HUD ──────────────────────────────────────
  local onCnt=0
  for _,o in ipairs(objects) do if o.onPed then onCnt=onCnt+1 end end
  local def=LEVELS[level] or LEVELS[#LEVELS]

  local hx,hy,hz = lovr.headset.getPosition()
  local dx = hx - hudPos.x
  local dz = hz - hudPos.z
  local yaw = math.atan2(dx, dz)

  pass:push()
  pass:translate(hudPos.x, hudPos.y, hudPos.z)
  pass:rotate(yaw, 0,1,0)

  pass:setColor(0.04, 0.06, 0.14, 0.82)
  pass:plane(0, 0, 0, 0.55, 0.26)

  pass:setColor(0.3, 0.5, 0.9, 0.5)
  pass:plane(0, 0, -0.001, 0.57, 0.28)
  pass:setColor(0.04, 0.06, 0.14, 0.82)
  pass:plane(0, 0, -0.0005, 0.55, 0.26)

  pass:setColor(0.75, 0.92, 1, 1)
  pass:text(string.format("✦ FLOAT  ·  Level %d: %s", level, def.label),
    0, 0.088, 0, 0.021)

  pass:setColor(0.12, 0.15, 0.25, 1)
  pass:plane(0, 0.048, 0.001, 0.36, 0.013)
  local frac = onCnt / math.max(#objects, 1)
  if frac > 0 then
    pass:setColor(0.3, 1, 0.65, 1)
    pass:plane(-0.18 + 0.18*frac, 0.048, 0.002, 0.36*frac, 0.013)
  end

  pass:setColor(0.85, 1, 0.88, 1)
  pass:text(string.format("Orbs on pedestal: %d / %d", onCnt, #objects),
    0, 0.025, 0, 0.017)

  -- Scale hint changes when scaling is active
  if scaleState then
    local pulse = 0.6 + math.sin(t*6)*0.4
    pass:setColor(pulse, 1, pulse, 1)
    pass:text("✦ SCALING — pinch apart/together",
      0, -0.01, 0, 0.013)
  else
    pass:setColor(0.5, 0.52, 0.65, 1)
    pass:text("Grab: Pinch/Trigger  Move: L-Stick  Height: R-Stick Y  Scale: Both hands",
      0, -0.01, 0, 0.011)
  end

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