-- Parameters

local TERSCA = 96
local FLOATPER = 512
local FLOATFAC = 2
local FLOATOFF = -0.2
local YSURFMAX = 256
local YSURFCEN = 0
local YSURFMIN = -256
local YUNDERCEN = -512
local UNDERFAC = 0.0001
local UNDEROFF = -0.2
local YWAT = 1
local YLAVA = -528
local LUXCHA = 1 / 9 ^ 3

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

-- Nodes
 
-- Dummy lux ore so that lux ore light spread ABM only runs once per lux node
minetest.register_node("levels:luxoff", {
	description = "Dark Lux Ore",
	tiles = {"levels_luxore.png"},
	light_source = 14,
	groups = {immortal=1},
	sounds = default.node_sound_glass_defaults(),
})

minetest.register_node("levels:luxore", {
	description = "Lux Ore",
	tiles = {"levels_luxore.png"},
	light_source = 14,
	groups = {cracky=3},
	sounds = default.node_sound_glass_defaults(),
})
 
-- ABM to spread lux ore light
-- Luxoff is only placed above stone to stop droop when replaced with luxore:
-- .. and data[(vi - ystride)] == c_stone then

minetest.register_abm({
	nodenames = {"levels:luxoff"},
	interval = 7,
	chance = 1,
	action = function(pos, node)
		minetest.remove_node(pos)
		minetest.place_node(pos, {name="levels:luxore"})
	end,
})

-- Stuff

local floatper = math.pi / FLOATPER

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
	
	local c_luxoff  = minetest.get_content_id("levels:luxoff")
	local c_luxore  = minetest.get_content_id("levels:luxore")

	local sidelen = x1 - x0 + 1
	local ystride = sidelen + 32
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
				local grad = (YSURFCEN - y) / TERSCA
				if y > YSURFMAX then
					grad = math.max(
						-FLOATFAC * math.abs(math.cos((y - YSURFMAX) * floatper)),
						grad
					)
				elseif y < YSURFMIN then
					grad = math.min(
						UNDERFAC * (y - YUNDERCEN) ^ 2 + UNDEROFF,
						grad
					)
				end

				local density = n_terrain + grad
				if density > 0 then
					if math.random() < LUXCHA and y < YSURFMIN
					and density < 0.01 and data[(vi - ystride)] == c_stone then
						data[vi] = c_luxoff
					else
						data[vi] = c_stone
					end
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

