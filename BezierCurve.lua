--==============================
-- Bezier Curve Class
--==============================
-- Created by: E.T. Garcia
-- Created on: 2/14/2012

local BezierCurve = {}

function BezierCurve.new(p0, c0, p1, c1, isDebug)
	-- Creates Instance
	local self = {}
	
	--==============================
	-- Public Variables
	--==============================
	self.gfx = nil
	
	--==============================
	-- Local Variables
	--==============================
	local isDebug = isDebug or false
	local p0 = display.newCircle(p0.x, p0.y, 5)
	local p1 = display.newCircle(p1.x, p1.y, 5)
	local c0 = display.newCircle(c0.x, c0.y, 5)
	local c1 = display.newCircle(c1.x, c1.y, 5)
	local hasMoved = false
	local handles = {p0, p1, c0, c1}
	local color = {255,128,0}
	local lines
	
	--==============================
	-- Local Functions
	--==============================
	
	-- Returns the square distance between two points
	local function sqDist(pt0, pt1)
		local dx = pt0.x - pt1.x
		local dy = pt0.y - pt1.y
		return dx*dx + dy*dy
	end
	
	-- Calculates line segments and draws them (into self.gfx)
	local function drawBezier(granularity, r, g, b)
		-- Setup Variables
		granularity = granularity or 50
		r = r or color[1]
		g = g or color[2]
		b = b or color[3]
		local segments = {}
		local p = bezierPoints
		local inc = (1.0 / granularity)
		local t = 0
		local t1 = 0
		
		-- For granularity, complete crazy formula to compute segments
		for i = 1, granularity do
			t1 = 1.0 - t
			local x = (t1*t1*t1) * p0.x
			x = x + (3*t)*(t1*t1) * c0.x
			x = x + (3*t*t)*(t1) * c1.x
			x = x + (t*t*t) * p1.x
			
			local y = (t1*t1*t1) * p0.y
			y = y + (3*t)*(t1*t1) * c0.y
			y = y + (3*t*t)*(t1) * c1.y
			y = y + (t*t*t) * p1.y
			
			table.insert(segments, {x = x, y = y})
			t = t + inc
		end
		
		-- Add last segment if it doesn't quite reach the last point
		if (sqDist(segments[#segments],p1) < 10*10) then --if close, just change last point to end point
			segments[#segments] = {x = p1.x, y = p1.y}
		else --otherwise, add the last point
			table.insert(segments, {x = p1.x, y = p1.y})
		end
		
		-- Remove previous bezierCurve and draw segments
		if (self.gfx) then self.gfx:removeSelf() end
		self.gfx = display.newLine(segments[1].x, segments[1].y, segments[2].x, segments[2].y)
		for i = 3, #segments do
			self.gfx:append(segments[i].x, segments[i].y)
		end
		
		-- Set color and width of bezier curve (aka lines)
		self.gfx:setColor(r,g,b)
		self.gfx.width = 4
	end

	-- Move debug handles around
	local function dragHandles(event)
		local t = event.target
		if (event.phase == "began") then
			t.parent:insert(t)
			display.getCurrentStage():setFocus(t)
			t.isFocus = true
		elseif (t.isFocus) then
			if (event.phase == "moved") then
				t.x = event.x
				t.y = event.y
				hasMoved = true
			elseif (event.phase == "ended" or event.phase == "cancelled") then
				display.getCurrentStage():setFocus(nil)
				t.isFocus = false
				hasMoved = false
				drawBezier()
			end
		end
	end

	-- Redraw curve if moved
	local function update(event)
		if (hasMoved) then
			hasMoved = false
			if (lines) then lines:removeSelf() end
			lines = display.newGroup()
			display.newLine(lines,p0.x,p0.y,c0.x,c0.y)
			display.newLine(lines,p1.x,p1.y,c1.x,c1.y)
			drawBezier(10,128,128,128)
		end
	end

	--==============================
	-- Public Functions
	--==============================
	function self:toggleDebug()
		if (isDebug) then
			for i = 1, #handles do
				handles[i].isVisible = true
				handles[i]:addEventListener("touch", dragHandles)
			end
			Runtime:addEventListener("enterFrame", update)
		else
			Runtime:removeEventListener("enterFrame", update)
			for i = 1, #handles do
				handles[i].isVisible = false
				handles[i]:removeEventListener("touch", dragHandles)
			end
		end
		hasMoved = true
		isDebug = not(isDebug)
	end
	
	function self:removeSelf()
		if (self.gfx) then self.gfx:removeSelf() end
		for i = 1, #handles do
			if (handles[i]) then handles[i]:removeSelf() end
		end
		self.gfx = nil
		handles = nil
		colors = nil
	end
	
	--==============================
	-- Constructor
	--==============================
	p0:setFillColor(255,0,0)
	p1:setFillColor(255,0,0)
	c0:setFillColor(255,255,0)
	c1:setFillColor(255,255,0)
	self:toggleDebug(isDebug)
	drawBezier()
	
	-- Return Instance
	return self
end

return BezierCurve