display.setStatusBar(display.HiddenStatusBar)

-- Set a nice grey background for the program
local background = display.newRect(0, 0, display.contentWidth, display.contentHeight)
background:setFillColor(64,64,64)

-- Program variables
local points = {}
local hasMoved = false
local line
local pointsGroup
local mode = "drawLine"

-- Returns square distance (faster than regular distance)
local function squareDistance(pointA, pointB)
	local dx = pointA.x - pointB.x
	local dy = pointA.y - pointB.y
	return dx*dx + dy*dy
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
	
	print(#points, #newPoints)
	points = newPoints
	hasMoved = true
end

local function perpendicularDistance(p0, p1, p2) --p1 and p2 form the line
	if (p1.x == p2.x) then
		return math.abs(p0.x - p1.x)
	end
	local m = (p2.y - p1.y) / (p2.x - p1.x) --slope
	local b = p1.y - m * p1.x --offset
	local dist = math.abs(p0.y - m * p0.x - b)
	dist = dist / math.sqrt(m*m + 1)
	return dist
end

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

-- Touch event that places points into an array
local function plotPoints(event)
	if (mode == "drawLine") then
		if (event.phase == "ended") then
			mode = "simplifyLine"
		else
			local point = {x = event.x, y = event.y}
			table.insert(points, point)
			hasMoved = true
		end
	elseif (mode == "simplifyLine") then
		if (event.phase == "ended") then
			polySimplify(10)
			for i = 1, 3 do
				local pts = {}
				for i = 1, #points do table.insert(pts, points[i]) end
				local pt = #points
				points = DouglasPeucker(pts, 1)
				print(pt, #points)
			end
			hasMoved = true
			mode = "createCurves"
		end
	elseif (mode == "createCurves") then
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

--[[ Quick BezierCurve Code
local BezierCurve = require "BezierCurve"
local bezier = BezierCurve.new({x = 50, y = 50},{x = 50, y = 200},{x = 300, y = 50}, {x = 300, y = 200}, true)
local bezier1 = BezierCurve.new({x = 150, y = 150},{x = 150, y = 300},{x = 400, y = 150}, {x = 400, y = 300}, true)
]]--