-- Parameters

local TERSCA = 96
local TSPIKE = 1.1
local SPIKEAMP = 2000
local TSTONE = 0.03
local STABLE = 2

local FLOATPER = 512
local FLOATFAC = 2
local FLOATOFF = -0.2

local YSURFMAX = 256
local YSURFCEN = 0
local YSAND = 4
local YWAT = 1
local YSURFMIN = -256

local YUNDERCEN = -512
local YLAVA = -528
local UNDERFAC = 0.0001
local UNDEROFF = -0.2
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

-- 2D noise

local np_spike = {
	offset = 0,
	scale = 1,
	spread = {x=128, y=128, z=128},
	seed = -188900,
	octaves = 3,
	persist = 0.5,
	lacunarity = 2.0,
	flags = "noeased"
}

-- Nodes
 
minetest.register_node("levels:grass", {
	description = "Grass",
	tiles = {"default_grass.png", "default_dirt.png", "default_grass.png"},
	groups = {crumbly=3},
	sounds = default.node_sound_dirt_defaults({
		footstep = {name="default_grass_footstep", gain=0.25},
	}),
})

-- Dummy lux ore so that lux ore light spread ABM only runs once per lux node
minetest.register_node("levels:luxoff", {
	description = "Dummy Lux Ore",
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
	interval = 5,
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
local nobj_spike = nil

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	local t0 = os.clock()
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	print ("[levels] chunk minp ("..x0.." "..y0.." "..z0..")")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_stone  = minetest.get_content_id("default:stone")
	local c_sand  = minetest.get_content_id("default:sand")
	local c_water  = minetest.get_content_id("default:water_source")
	local c_lava   = minetest.get_content_id("default:lava_source")
	
	local c_grass = minetest.get_content_id("levels:grass")
	local c_luxoff = minetest.get_content_id("levels:luxoff")
	local c_luxore = minetest.get_content_id("levels:luxore")

	local sidelen = x1 - x0 + 1
	local ystride = sidelen + 32
	--local zstride = ystride ^ 2
	local chulens3d = {x=sidelen, y=sidelen+16, z=sidelen}
	local chulens2d = {x=sidelen, y=sidelen, z=1}
	local minpos3d = {x=x0, y=y0-16, z=z0}
	local minpos2d = {x=x0, y=z0}
	
	local nobj_terrain = nobj_terrain or minetest.get_perlin_map(np_terrain, chulens3d)
	local nobj_spike = nobj_spike or minetest.get_perlin_map(np_spike, chulens2d)
	
	local nvals_terrain = nobj_terrain:get3dMap_flat(minpos3d)
	local nvals_spike = nobj_spike:get2dMap_flat(minpos2d)

	local ni3d = 1
	local ni2d = 1
	local stable = {}
	for z = z0, z1 do
		for x = x0, x1 do
			local si = x - x0 + 1
			stable[si] = 0
		end
		for y = y0 - 16, y1 do
			local vi = area:index(x0, y, z)
			for x = x0, x1 do
				local si = x - x0 + 1

				local n_terrain = nvals_terrain[ni3d]
				local n_spike = nvals_spike[ni2d]
				local spikeoff = 0
				if n_spike > TSPIKE then
					spikeoff = (n_spike - TSPIKE) ^ 4 * SPIKEAMP
				end
				local grad = (YSURFCEN - y) / TERSCA + spikeoff
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
				if y < y0 then
					if density >= TSTONE then
						stable[si] = stable[si] + 1
					elseif density <= 0 then
						stable[si] = 0
					end
				elseif y >= y0 and y <= y1 then
					if density >= TSTONE then
						if math.random() < LUXCHA and y < YSURFMIN
						and density < 0.01 and data[(vi - ystride)] == c_stone then
							data[vi] = c_luxoff
						else
							data[vi] = c_stone
						end
						stable[si] = stable[si] + 1
					elseif density > 0 and density < TSTONE
					and stable[si] >= STABLE and y > YSURFMIN then
						if y <= YSAND then
							data[vi] = c_sand
						else
							data[vi] = c_grass
						end
					elseif y > YSURFMIN and y <= YWAT then
						data[vi] = c_water
						stable[si] = 0
					elseif y <= YLAVA then
						data[vi] = c_lava
						stable[si] = 0
					else -- air
						stable[si] = 0
					end
				end

				ni3d = ni3d + 1
				ni2d = ni2d + 1
				vi = vi + 1
			end
			ni2d = ni2d - sidelen
		end
		ni2d = ni2d + sidelen
	end
	
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)
	vm:update_liquids()

	local chugent = math.ceil((os.clock() - t0) * 1000)
	print ("[levels] "..chugent.." ms")
end)

