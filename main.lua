display.setStatusBar(display.HiddenStatusBar)

-- Require the following objects
local BezierCurve = require "BezierCurve"

-- Set a nice grey background for the program
local background = display.newRect(0, 0, display.contentWidth, display.contentHeight)
background:setFillColor(64,64,64)

-- Program variables
local points = {}
local hasMoved = false
local line
local pointsGroup
local mode = "drawLine"
local hud = display.newText(mode, 10, display.contentHeight-30, native.systemFontBold, 25)
local bezierPath = {}
local player

-- Returns square distance (faster than regular distance)
local function squareDistance(pointA, pointB)
	local dx = pointA.x - pointB.x
	local dy = pointA.y - pointB.y
	return dx*dx + dy*dy
end

-- Returns distance between two points
local function distance(pointA, pointB)
	return math.sqrt(squareDistance(pointA, pointB))
end

-- Returns perpendicular distance from point p0 to line defined by p1,p2
local function perpendicularDistance(p0, p1, p2)
	if (p1.x == p2.x) then
		return math.abs(p0.x - p1.x)
	end
	local m = (p2.y - p1.y) / (p2.x - p1.x) --slope
	local b = p1.y - m * p1.x --offset
	local dist = math.abs(p0.y - m * p0.x - b)
	dist = dist / math.sqrt(m*m + 1)
	return dist
end

-- Returns a normalized vector
local function normalizeVector(v)
	local magnitude = distance({x = 0, y = 0}, v)
	return {x = v.x/magnitude, y = v.y/magnitude}
end

-- Simplifies the path by eliminating points that are too close
local function polySimplify(tolerance)
	local newPoints = {}
	table.insert(newPoints, points[1])
	local lastPoint = points[1]
	
	local squareTolerance = tolerance*tolerance
	for i = 2, #points do
		if (squareDistance(points[i], lastPoint) >= squareTolerance) then
			table.insert(newPoints, points[i])
			lastPoint = points[i]
		end
	end
	points = newPoints
	hasMoved = true
end

-- Algorithm to simplify a curve and keep major curve points
local function DouglasPeucker(pts, epsilon)
	--Find the point with the maximum distance
	local dmax = 0
	local index = 0
	for i = 3, #pts do 
		d = perpendicularDistance(pts[i], pts[1], pts[#pts])
		if d > dmax then
			index = i
			dmax = d
		end
	end
	
	local results = {}
	
	--If max distance is greater than epsilon, recursively simplify
	if dmax >= epsilon then
		--Recursive call
		local tempPts = {}
		for i = 1, index-1 do table.insert(tempPts, pts[i]) end
		local results1 = DouglasPeucker(tempPts, epsilon)
		
		local tempPts = {}
		for i = index, #pts do table.insert(tempPts, pts[i]) end
		local results2 = DouglasPeucker(tempPts, epsilon)

		-- Build the result list
		for i = 1, #results1-1 do table.insert(results, results1[i]) end
		for i = 1, #results2 do table.insert(results, results2[i]) end
	else
		for i = 1, #pts do table.insert(results, pts[i]) end
	end
	
	--Return the result
	return results
end

-- Creates a bezier path that crosses through all points
local function bezierInterpolation()
	local p = points
	if (#p < 2) then return true end
	
	local scale = 0.3
	local c = {}
	
	for i = 1, #p do
		if (i == 1) then
			local scale = scale * 10
			local tangent = {x = p[2].x - p[1].x, y = p[2].y - p[1].y}
			local nT = normalizeVector(tangent)
			local c1 = {x = p[1].x + scale * nT.x, y = p[1].y + scale * nT.y}
			table.insert(c, p[1])
			table.insert(c, c1)
		elseif (i == #p) then
			local scale = scale * 10
			local tangent = {x = p[#p].x - p[#p-1].x, y = p[#p].y - p[#p-1].y}
			local nT = normalizeVector(tangent)
			local c2 = {x = p[#p].x - scale * nT.x, y = p[#p].y - scale * nT.y}
			table.insert(c, p[#p])
			table.insert(c, c2)
		else
			local tangent = {x = p[i+1].x - p[i-1].x, y = p[i+1].y - p[i-1].y}
			local nT = normalizeVector(tangent)
			local dist1 = distance(p[i-1],p[i])
			local dist2 = distance(p[i],p[i+1])
			local c1 = {x = p[i].x - scale * nT.x * dist1, y = p[i].y - scale * nT.y * dist1}
			local c2 = {x = p[i].x + scale * nT.x * dist2, y = p[i].y + scale * nT.y * dist2}
			table.insert(c, p[i])
			table.insert(c, c1)
			table.insert(c, p[i])
			table.insert(c, c2)
		end
	end
	
	for i = 1, #c, 4 do
		local bezier = BezierCurve.new(c[i], c[i+1], c[i+2], c[i+3])
		table.insert(bezierPath, bezier)
	end
end

-- Move player along the curve
local function movePlayer(event)
	-- If we made the player, let's move!
	if (player) then
		-- We check if we are still on the path
		while bezierPath[player.pathPos] do
			-- Loop through curve until we are far enough away to move player (we don't want to move player 1px at a time)
			while bezierPath[player.pathPos]:pointOnSegment(player.curveSegment) do
				-- If we are on the curve and we are further than the distance we need to go, move to next point!
				local nextPt = bezierPath[player.pathPos]:pointOnSegment(player.curveSegment)
				if (squareDistance(player, nextPt) >= player.speed*player.speed) then
					-- I know this rotation equation is a bit intimidating, but lets looks at it.
					-- Arctan( change in y, change in x) gets angle between two points, change to degrees, add 90 so object points east at 0 degrees (not north)
					-- modulus 360 (because I don't like numbers outside of 360! aka 380 % 360 = 20)
					player.rotation = (math.deg(math.atan2(nextPt.y - player.y, nextPt.x - player.x))+90)%360
					player.x = nextPt.x
					player.y = nextPt.y
					return true
				end
				-- iterate through points on the curve
				player.curveSegment = player.curveSegment + 1
			end
			-- iterate through curves
			player.pathPos = player.pathPos + 1
			player.curveSegment = 2 -- skip one since 1 is most likely where player is anyway
		end
		-- If we are off the curve, we are done!
		Runtime:removeEventListener("enterFrame", movePlayer)
	-- If no player was made, let's make him (or her)
	else
		-- A box with a circle front
		player = display.newGroup()
		display.newRect(player,-10,-10,20,20)
		display.newCircle(player,0,-10,8)
		player[2]:setFillColor(0,0,64)
		player.speed = 8 -- how fast the player can move per frame
		player.pathPos = 1
		player.curveSegment = 1
		local pos = bezierPath[player.pathPos]:pointOnSegment(player.curveSegment)
		if (pos) then
			player.x = pos.x
			player.y = pos.y
		end
	end
	return true
end

-- Touch event that places points into an array
local function plotPoints(event)
	if (mode == "drawLine") then
		if (event.phase == "ended") then
			print("You have started with "..#points.." points.")
			mode = "simplifyLine"
			hud.text = mode
		else
			local point = {x = event.x, y = event.y}
			table.insert(points, point)
			hasMoved = true
		end
	elseif (mode == "simplifyLine" and event.phase == "ended") then
		polySimplify(10)
		print("After polySimplify(10) you have "..#points.." points.")
		for i = 1, 3 do
			local pts = {}
			for i = 1, #points do table.insert(pts, points[i]) end
			local pt = #points
			points = DouglasPeucker(pts, 1)
		end
		print("After 3 iterations of DouglasPeucker() you have "..#points.." points.")
		hasMoved = true
		mode = "createCurves"
		hud.text = mode
	elseif (mode == "createCurves" and event.phase == "ended") then
		bezierInterpolation()
		print("In the end you have "..#bezierPath.." bezier curves defined by "..(4*#bezierPath).." points.")
		mode = "deleteCurve"
		hud.text = mode
	elseif (mode == "deleteCurve" and event.phase == "ended") then
		if (line) then line:removeSelf() end
		if (pointsGroup) then pointsGroup:removeSelf() end
		line = nil
		pointsGroup = nil
		points = {}
		mode = "movePlayer"
		hud.text = mode
	elseif (mode == "movePlayer" and event.phase == "ended") then
		Runtime:addEventListener("enterFrame", movePlayer)
		mode = "addHandles"
		hud.text = mode
	elseif (mode == "addHandles" and event.phase == "ended") then
		for i = 1, #bezierPath do
			bezierPath[i]:toggleDebug()
		end
		mode = "editHandles"
		hud.text = mode
	elseif (mode == "editHandles" and event.phase == "ended") then
	end
end

-- Draw new lines every frame
local function drawLines()
	if (hasMoved == false) then
		return true
	end
	hasMoved = false
	
	-- Draw the line
	if (line) then line:removeSelf() end
	if (#points > 1) then
		line = display.newLine(points[1].x, points[1].y, points[2].x, points[2].y)
		for i = 3, #points do
			line:append(points[i].x, points[i].y)
		end
		line:setColor(255,255,0)
		line.width = 12
	end
	
	-- Draw the points
	if (pointsGroup) then pointsGroup:removeSelf() end
	pointsGroup = display.newGroup()
	for i = 1, #points do
		local pt = display.newCircle(points[i].x, points[i].y, 6)
		pt:setFillColor(255,0,0)
		pointsGroup:insert(pt)
	end
end

-- Add listeners
Runtime:addEventListener("touch", plotPoints)
Runtime:addEventListener("enterFrame", drawLines)