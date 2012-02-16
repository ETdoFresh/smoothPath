display.setStatusBar(display.HiddenStatusBar)

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

--[[ An Algorithm for Automatically Fitting Digitized Curves
by Philip J. Schneider
from "Graphics Gems", Academic Press, 1990

 *  FitCubic :
 *  	Fit a Bezier curve to a (sub)set of digitized points
local function FitCubic(pts, tHat1, tHat2, error)
    BezierCurve	bezCurve;		--Control points of fitted Bezier curve
    double	*u;					--  Parameter values for point  
    double	*uPrime;			--  Improved parameter values 
    double	maxError;			--  Maximum fitting error	 
    int		splitPoint;			--  Point to split point set at	 
    int		nPts;				--  Number of points in subset  
    double	iterationError;		--Error below which you try iterating  
    int		maxIterations = 4;	--  Max times to try iterating  
    Vector2	tHatCenter;   		-- Unit tangent vector at splitPoint 
	Vector2 tHatLeft,tHatRight;	-- om vector handles mogelijk te maken 
    int		i;

    iterationError = error * error;

    --  Use heuristic if region only has two points in it 
    if (#pts == 2) {
	    local dist = math.sqrt(squareDistance(pts[1],pts[#pts])) / 3.0;

		bezCurve = (Point2 *)mallocN(4 * sizeof(Point2), "FitCubic");
		bezCurve[0] = d[first];
		bezCurve[3] = d[last];
		V2Add(&bezCurve[0], V2Scale(&tHat1, dist), &bezCurve[1]);
		V2Add(&bezCurve[3], V2Scale(&tHat2, dist), &bezCurve[2]);
		AddBezierSeg(bezCurve);
		freeN(bezCurve);
		return;
    }

    --  Parameterize points, and attempt to fit curve 
    u = ChordLengthParameterize(d, first, last);
    bezCurve = GenerateBezier(d, first, last, u, tHat1, tHat2);

    --  Find max deviation of points to fitted curve 
    maxError = ComputeMaxError(d, first, last, bezCurve, u, &splitPoint);

	if (maxError < error) {
		AddBezierSeg(bezCurve);
		freeN(bezCurve);
		freeN(u);
		return;
    }
	
    --  If error not too large, try some reparameterization  
    --  and iteration 
    if (maxError < iterationError) {
		for (i = 0; i < maxIterations; i++) {
	    	uPrime = Reparameterize(d, first, last, u, bezCurve);
			freeN(bezCurve);
	    	bezCurve = GenerateBezier(d, first, last, uPrime, tHat1, tHat2);
	    	maxError = ComputeMaxError(d, first, last, bezCurve, uPrime, &splitPoint);
	    	if (maxError < error) {
				AddBezierSeg(bezCurve);
				freeN(bezCurve);
				freeN(u);
				freeN(uPrime);
				return;
			}
			freeN((char *)u);
			u = uPrime;
		}
	}
	freeN(bezCurve);
	freeN(u);
	
    -- Fitting failed -- split at max error point and fit recursively 
	
	if (splitmode != SPLT_ERR) splitPoint = (first + last) / 2;
	if (splitmode == SPLT_EXT) {
		-- zoek naar extreem (x of y) in spline 
		-- degene het dichst bij het midden wint 
		-- misschien dat ook naar 45 gekeken kan worden 
		
		char * splitarr;	-- jes or no split 
		long i, c;
		long dist, mdist, best;
		float dx, dy;
		
		splitarr = (char *) mallocN(nPts, "FitCubic2");
		
		for (i = first; i < last; i ++){
			c = 0;
			dx = d[i].x - d[i + 1].x;
			dy = d[i].y - d[i + 1].y;
			if (dx < 0.0) c |= 1;
			else if (dx > 0.0) c |= 2;
			if (dy < 0.0) c |= 4;
			else if (dy > 0.0) c |= 8;
			--if (fabsf(dx) < fabsf(dy)) c |= 16;
			splitarr[i - first] = c;
		}
		
		-- zoek naar omslagpunten 
		for (i = 0; i < nPts - 1; i++) splitarr[i] ^= splitarr[i + 1];
		
		best = splitPoint; mdist = 0xffffff;
		-- eventueel nog optimaliseren naar meerdere omslagen na elkaar ?? 
		for (i = 1; i < nPts - 3; i++) {
			if (splitarr[i]) {
				dist = (i + first + 1) - splitPoint;
				if (dist < 0) dist = -dist;
				if (dist < mdist) {
					best = i + first + 1;
					mdist = dist;
				}
			}
		}
		splitPoint = best;
		freeN(splitarr);
	}
	
-------
    tHatCenter = ComputeCenterTangent(d, splitPoint);
    FitCubic(d, first, splitPoint, tHat1, tHatCenter, error);
    V2Negate(&tHatCenter);
    FitCubic(d, splitPoint, last, tHatCenter, tHat2, error);
-------
    ComputeCenterTangents(d, splitPoint, &tHatLeft, &tHatRight);
    FitCubic(d, first, splitPoint, tHat1, tHatLeft, error);
    FitCubic(d, splitPoint, last, tHatRight, tHat2, error);
}

/*
 *  NewtonRaphsonRootFind :
 *	Use Newton-Raphson iteration to find better root.
 */
static double NewtonRaphsonRootFind(Q, P, u)
    BezierCurve	Q;			/*  Current fitted curve	*/
    Point2 		P;		/*  Digitized point		*/
    double 		u;		/*  Parameter value for "P"	*/
{
    double 		numerator, denominator;
    Point2 		Q1[3], Q2[2];	/*  Q' and Q''			*/
    Point2		Q_u, Q1_u, Q2_u; /*u evaluated at Q, Q', & Q''	*/
    double 		uPrime;		/*  Improved u			*/
    int 		i;
    
    /* Compute Q(u)	*/
    Q_u = Bezier(3, Q, u);
    
    /* Generate control vertices for Q'	*/
    for (i = 0; i <= 2; i++) {
		Q1[i].x = (Q[i+1].x - Q[i].x) * 3.0;
		Q1[i].y = (Q[i+1].y - Q[i].y) * 3.0;
    }
    
    /* Generate control vertices for Q'' */
    for (i = 0; i <= 1; i++) {
		Q2[i].x = (Q1[i+1].x - Q1[i].x) * 2.0;
		Q2[i].y = (Q1[i+1].y - Q1[i].y) * 2.0;
    }
    
    /* Compute Q'(u) and Q''(u)	*/
    Q1_u = Bezier(2, Q1, u);
    Q2_u = Bezier(1, Q2, u);
    
    /* Compute f(u)/f'(u) */
    numerator = (Q_u.x - P.x) * (Q1_u.x) + (Q_u.y - P.y) * (Q1_u.y);
    denominator = (Q1_u.x) * (Q1_u.x) + (Q1_u.y) * (Q1_u.y) +
		      	  (Q_u.x - P.x) * (Q2_u.x) + (Q_u.y - P.y) * (Q2_u.y);
    
    /* u = u - f(u)/f'(u) */
    uPrime = u - (numerator/denominator);
    return (uPrime);
}

]]

local function bezierInterpolation()
	local p = points
	if (#p < 2) then return true end
	
	local scale = 1
	local c = {}
	
	for i = 1, #p do
		if (i == 1) then
			local tangent = {x = p[2].x - p[1].x, y = p[2].y - p[1].y}
			local c1 = {x = p[1].x + scale * tangent.x, y = p[1].y + scale * tangent.y}
			table.insert(c, p[1])
			table.insert(c, c1)
		elseif (i == #p) then
			local tangent = {x = p[#p].x - p[#p-1].x, y = p[#p].y - p[#p-1].y}
			local c2 = {x = p[#p].x - scale * tangent.x, y = p[#p].y - scale * tangent.y}
			table.insert(c, p[#p])
			table.insert(c, c2)
		else
			local tangent = {x = p[i+1].x - p[i-1].x, y = p[i+1].y - p[i-1].y}
			local tDist = math.sqrt(squareDistance({x = 0, y = 0}, tangent))
			local tx1Dist = math.abs((p[i].x - p[i-1].x) / tDist)
			local ty1Dist = math.abs((p[i].y - p[i-1].y) / tDist)
			local tx2Dist = math.abs((p[i+1].x - p[i].x) / tDist)
			local ty2Dist = math.abs((p[i+1].y - p[i].y) / tDist)
			local c1 = {x = p[i].x - scale * tangent.x * tx1Dist, y = p[i].y - scale * tangent.y * ty1Dist}
			local c2 = {x = p[i].x + scale * tangent.x * tx2Dist, y = p[i].y + scale * tangent.y * ty2Dist}
			table.insert(c, p[i])
			table.insert(c, c1)
			table.insert(c, p[i])
			table.insert(c, c2)
		end
	end
	
	for i = 1, #c, 4 do
		local bezier = BezierCurve.new(c[i], c[i+1], c[i+2], c[i+3], true)
	end
end

-- Touch event that places points into an array
local function plotPoints(event)
	if (mode == "drawLine") then
		if (event.phase == "ended") then
			mode = "simplifyLine"
			hud.text = mode
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
			hud.text = mode
		end
	elseif (mode == "createCurves") then
		if (event.phase == "ended") then
			bezierInterpolation()
			mode = "deleteCurve"
			hud.text = mode
		end
	elseif (mode == "deleteCurve") then
		if (event.phase == "ended") then
			if (line) then line:removeSelf() end
			if (pointsGroup) then pointsGroup:removeSelf() end
			line = nil
			pointsGroup = nil
			points = {}
			--[[mode = "drawLine"
			hud.text = mode]]--
		end
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