-- Parameters

local TERSCA = 96
local YFLOATCEN = 512
local YSURFMAX = 256
local YSURFCEN = 0
local YSURFMIN = -256
local YUNDERCEN = -512
local YWAT = 1
local YLAVA = YUNDERCEN - TERSCA / 4

-- Noise parameters

-- 3D noise

local np_terrain = {
	offset = 0,
	scale = 1,
	spread = {x=384, y=192, z=384},
	seed = 5900033,
	octaves = 5,
	persist = 0.63,
	lacunarity = 2.0,
	--flags = ""
}

-- Initialize noise objects to nil

local nobj_terrain = nil

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)

	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	
	print ("chunk minp ("..x0.." "..y0.." "..z0..")")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_stone = minetest.get_content_id("default:stone")
	local c_water = minetest.get_content_id("default:water_source")
	local c_lava  = minetest.get_content_id("default:lava_source")
	
	local sidelen = x1 - x0 + 1
	local chulens3d = {x=sidelen, y=sidelen, z=sidelen}
	local minpos3d = {x=x0, y=y0, z=z0}
	
	local nobj_terrain = nobj_terrain or minetest.get_perlin_map(np_terrain, chulens3d)
	
	local nvals_terrain = nobj_terrain:get3dMap_flat(minpos3d)

	local ni3d = 1
	for z = z0, z1 do
		for y = y0, y1 do
			local vi = area:index(x0, y, z)
			for x = x0, x1 do
				local n_terrain = nvals_terrain[ni3d]
				local grad

				if y > YFLOATCEN then
					grad = (YFLOATCEN - y) / TERSCA
				elseif y > YSURFMAX and y <= YFLOATCEN then
					grad = (y - YFLOATCEN) / TERSCA
				elseif y >= YSURFMIN and y <= YSURFMAX then
					grad = (YSURFCEN - y) / TERSCA
				elseif y >= YUNDERCEN and y < YSURFMIN then
					grad = (y - YUNDERCEN) / TERSCA
				elseif y < YUNDERCEN then
					grad = (YUNDERCEN - y) / TERSCA
				end

				local density = n_terrain + grad
				if density > 0 then
					data[vi] = c_stone
				elseif y > YSURFMIN and y <= YWAT then
					data[vi] = c_water
				elseif y <= YLAVA then
					data[vi] = c_lava
				end

				ni3d = ni3d + 1
				vi = vi + 1
			end
		end
	end
	
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
	vm:update_liquids()
end)

