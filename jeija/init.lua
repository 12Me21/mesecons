-- |\    /| ____ ____  ____ _____   ____         _____
-- | \  / | |    |     |    |      |    | |\   | |
-- |  \/  | |___ ____  |___ |      |    | | \  | |____
-- |      | |        | |    |      |    | |  \ |     |
-- |      | |___ ____| |___ |____  |____| |   \| ____|
-- by Jeija and Minerd247
--
--
--
-- This mod adds mesecons[=minecraft redstone] and different receptors/effectors to minetest.
--
-- See the documentation on the forum for additional information, especially about crafting
--
--Quick Developer documentation for the mesecon API
--=================================================
--
--RECEPTORS
--
--A receptor is a node that emits power, e.g. a solar panel, a switch or a power plant.
--Usually you create two blocks per receptor that have to be switched when switching the on/off state: 
--	# An off-state node (e.g. jeija:mesecon_switch_off"
--	# An on-state node (e.g. jeija:mesecon_switch_on"
--The on-state and off-state nodes should be registered in the mesecon api, 
--so that the Mesecon circuit can be recalculated. This can be done using
--
--mesecon:add_receptor_node(nodename) -- for on-state node
--mesecon:add_receptor_node_off(nodename) -- for off-state node
--example: mesecon:add_receptor_node("jeija:mesecon_switch_on")
--
--Turning receptors on and off
--Usually the receptor has to turn on and off. For this, you have to
--	# Remove the node and replace it with the node in the other state (e.g. replace on by off)
--	# Send the event to the mesecon circuit by using the api functions
--		mesecon:receptor_on (pos, rules) } These functions take the position of your receptor
--		mesecon:receptor_off(pos, rules) } as their parameter.
--
--You can specify the rules using the rules parameter. If you don't want special rules, just leave it out
--
--!! If a receptor node is removed, the circuit should be recalculated. This means you have to
--send an mesecon:receptor_off signal to the api when the function in minetest.register_on_dignode
--is called.
--
--EFFECTORS
--
--A receptor is a node that uses power and transfers the signal to a mechanical, optical whatever
--event. e.g. the meselamp, the movestone or the removestone.
--
--There are two callback functions for receptors.
--	# function mesecon:register_on_signal_on (action)
--	# function mesecon:register_on_signal_off(action)
--
--These functions will be called for each block next to a mesecon conductor.
--
--Example: The removestone
--The removestone only uses one callback: The mesecon:register_on_signal_on function
--
--mesecon:register_on_signal_on(function(pos, node) -- As the action prameter you have to use a function
--	if node.name=="jeija:removestone" then -- Check if it really is removestone. If you wouldn't use this, every node next to mesecons would be removed
--		minetest.env:remove_node(pos) -- The action: The removestone is removed
--	end -- end of if
--end) -- end of the function, )=end of the parameters of mesecon:register_on_signal_on

-- SETTINGS
ENABLE_TEMPEREST=0
ENABLE_PISTON_ANIMATION=0
BLINKY_PLANT_INTERVAL=3

-- PUBLIC VARIABLES
mesecon={} -- contains all functions and all global variables
mesecon.actions_on={} -- Saves registered function callbacks for mesecon on
mesecon.actions_off={} -- Saves registered function callbacks for mesecon off
mesecon.pwr_srcs={} -- this is public for now
mesecon.pwr_srcs_off={} -- this is public for now
mesecon.wireless_receivers={}
mesecon.mvps_stoppers={}


-- MESECONS

minetest.register_node("jeija:mesecon_off", {
	drawtype = "raillike",
	tile_images = {"jeija_mesecon_off.png", "jeija_mesecon_curved_off.png", "jeija_mesecon_t_junction_off.png", "jeija_mesecon_crossing_off.png"},
	inventory_image = "jeija_mesecon_off.png",
	paramtype = "light",
	is_ground_content = true,
	walkable = false,
	selection_box = {
		type = "fixed",
	},
	material = minetest.digprop_constanttime(0.1),
})

minetest.register_node("jeija:mesecon_on", {
	drawtype = "raillike",
	tile_images = {"jeija_mesecon_on.png", "jeija_mesecon_curved_on.png", "jeija_mesecon_t_junction_on.png", "jeija_mesecon_crossing_on.png"},
	inventory_image = "jeija_mesecon_on.png",
	paramtype = "light",
	is_ground_content = true,
	walkable = false,
	selection_box = {
		type = "fixed",
	},
	material = minetest.digprop_constanttime(0.1),
	dug_item = 'node "jeija:mesecon_off" 1',
	light_source = LIGHT_MAX-11,
})

minetest.register_craft({
	output = 'node "jeija:mesecon_off" 16',
	recipe = {
		{'node "default:mese"'},
	}
})

function mesecon:is_power_on(p, x, y, z)
	local lpos = {}
	lpos.x=p.x+x
	lpos.y=p.y+y
	lpos.z=p.z+z
	local node = minetest.env:get_node(lpos)
	if node.name == "jeija:mesecon_on" or mesecon:is_receptor_node(node.name) then
		return 1
	end
	return 0
end

function mesecon:is_power_off(p, x, y, z)
	local lpos = {}
	lpos.x=p.x+x
	lpos.y=p.y+y
	lpos.z=p.z+z
	local node = minetest.env:get_node(lpos)
	if node.name == "jeija:mesecon_off" or mesecon:is_receptor_node_off(node.name) then
		return 1
	end
	return 0
end

function mesecon:turnon(p, x, y, z, firstcall, rules)
	if rules==nil then
		rules="default"
	end
	local lpos = {}
	lpos.x=p.x+x
	lpos.y=p.y+y
	lpos.z=p.z+z

	mesecon:activate(lpos)

	local node = minetest.env:get_node(lpos)
	if node.name == "jeija:mesecon_off" then
		--minetest.env:remove_node(lpos)
		minetest.env:add_node(lpos, {name="jeija:mesecon_on"})
		nodeupdate(lpos)
	end
	if node.name == "jeija:mesecon_off" or firstcall then
		local rules=mesecon:get_rules(rules)
		local i=1
		while rules[i]~=nil do 
			mesecon:turnon(lpos, rules[i].x, rules[i].y, rules[i].z, false, "default")
			i=i+1
		end
	end
end

function mesecon:turnoff(pos, x, y, z, firstcall, rules)
	if rules==nil then
		rules="default"
	end
	local lpos = {}
	lpos.x=pos.x+x
	lpos.y=pos.y+y
	lpos.z=pos.z+z

	local node = minetest.env:get_node(lpos)
	local connected = 0
	local checked = {}

	if not mesecon:check_if_turnon(lpos) then
		mesecon:deactivate(lpos)
	end

	if not(firstcall) and connected==0 then
		connected=mesecon:connected_to_pw_src(lpos, 0, 0, 0, checked)	
	end

	if connected == 0 and  node.name == "jeija:mesecon_on" then
		--minetest.env:remove_node(lpos)
		minetest.env:add_node(lpos, {name="jeija:mesecon_off"})
		nodeupdate(lpos)
	end


	if node.name == "jeija:mesecon_on" or firstcall then
		if connected == 0 then
			local rules=mesecon:get_rules(rules)
			local i=1
			while rules[i]~=nil do 
				mesecon:turnoff(lpos, rules[i].x, rules[i].y, rules[i].z, false, "default")
				i=i+1
			end
		end
	end
end


function mesecon:connected_to_pw_src(pos, x, y, z, checked, firstcall)
	local i=1
	local lpos = {}

	lpos.x=pos.x+x
	lpos.y=pos.y+y
	lpos.z=pos.z+z

	
	local node = minetest.env:get_node_or_nil(lpos)

	if not(node==nil) then
		repeat
			i=i+1
			if checked[i]==nil then checked[i]={} break end
			if  checked[i].x==lpos.x and checked[i].y==lpos.y and checked[i].z==lpos.z then 
				return 0
			end
		until false

		checked[i].x=lpos.x
		checked[i].y=lpos.y
		checked[i].z=lpos.z

		if mesecon:is_receptor_node(node.name) == true then -- receptor nodes (power sources) can be added using mesecon:add_receptor_node
			return 1
		end

		if node.name=="jeija:mesecon_on" or firstcall then -- add other conductors here
				local pw_source_found=0				
				local rules=mesecon:get_rules("default")
				local i=1
				while rules[i]~=nil do 
					pw_source_found=pw_source_found+mesecon:connected_to_pw_src(lpos, rules[i].x, rules[i].y, rules[i].z, checked, false)
					i=i+1
				end
			if pw_source_found > 0 then
				return 1
			end 
		end
	end
	return 0
end

function mesecon:check_if_turnon(pos)
	local getactivated=0
	local rules=mesecon:get_rules("default")
	local i=1
	while rules[i]~=nil do 
		getactivated=getactivated+mesecon:is_power_on(pos, rules[i].x, rules[i].y, rules[i].z)
		i=i+1
	end
	if getactivated > 0 then
		return true
	end
	return false
end

minetest.register_on_placenode(function(pos, newnode, placer)
	if mesecon:check_if_turnon(pos) then
		if newnode.name == "jeija:mesecon_off" then
			mesecon:turnon(pos, 0, 0, 0)		
		else
			mesecon:activate(pos)
		end
	end
end)

minetest.register_on_dignode(
	function(pos, oldnode, digger)
		if oldnode.name == "jeija:mesecon_on" then
			mesecon:turnoff(pos, 0, 0, 0, true)
		end	
	end
)

-- API API API API API API API API API API API API API API API API API API

function mesecon:add_receptor_node(nodename)
	local i=1
	repeat
		i=i+1
		if mesecon.pwr_srcs[i]==nil then break end
	until false
	mesecon.pwr_srcs[i]=nodename
end

function mesecon:add_receptor_node_off(nodename)
	local i=1
	repeat
		i=i+1
		if mesecon.pwr_srcs_off[i]==nil then break end
	until false
	mesecon.pwr_srcs_off[i]=nodename
end

function mesecon:receptor_on(pos, rules)
	mesecon:turnon(pos, 0, 0, 0, true, rules)
end

function mesecon:receptor_off(pos, rules)
	mesecon:turnoff(pos, 0, 0, 0, true, rules)
end

function mesecon:register_on_signal_on(action)
	local i	= 1	
	repeat
		i=i+1
		if mesecon.actions_on[i]==nil then break end
	until false
	mesecon.actions_on[i]=action
end

function mesecon:register_on_signal_off(action)
	local i	= 1	
	repeat
		i=i+1
		if mesecon.actions_off[i]==nil then break end
	until false
	mesecon.actions_off[i]=action
end



-- INTERNAL API


function mesecon:is_receptor_node(nodename)
	local i=1
	repeat
		i=i+1
		if mesecon.pwr_srcs[i]==nodename then return true end
	until mesecon.pwr_srcs[i]==nil
	return false
end

function mesecon:is_receptor_node_off(nodename)
	local i=1
	repeat
		i=i+1
		if mesecon.pwr_srcs_off[i]==nodename then return true end
	until mesecon.pwr_srcs_off[i]==nil
	return false
end


function mesecon:activate(pos)
	local node = minetest.env:get_node(pos)	
	local i = 1
	repeat
		i=i+1
		if mesecon.actions_on[i]~=nil then mesecon.actions_on[i](pos, node) 
		else break			
		end
	until false
end

function mesecon:deactivate(pos)
	local node = minetest.env:get_node(pos)	
	local i = 1
	local checked={}		
	repeat
		i=i+1
		if mesecon.actions_off[i]~=nil then mesecon.actions_off[i](pos, node) 
		else break			
		end
	until false
end


mesecon:register_on_signal_on(function(pos, node)
	if node.name=="jeija:meselamp_off" then
		--minetest.env:remove_node(pos)
		minetest.env:add_node(pos, {name="jeija:meselamp_on"})
		nodeupdate(pos)
	end
end)

mesecon:register_on_signal_off(function(pos, node)
	if node.name=="jeija:meselamp_on" then
		--minetest.env:remove_node(pos)
		minetest.env:add_node(pos, {name="jeija:meselamp_off"})
		nodeupdate(pos)
	end
end)

-- mesecon rules
function mesecon:get_rules(name)
	local rules={}
	rules[0]="dummy"
	if name=="default" then	
		table.insert(rules, {x=0,  y=0,  z=-1})
		table.insert(rules, {x=1,  y=0,  z=0})
		table.insert(rules, {x=-1, y=0,  z=0})
		table.insert(rules, {x=0,  y=0,  z=1})
		table.insert(rules, {x=1,  y=1,  z=0})
		table.insert(rules, {x=1,  y=-1, z=0})
		table.insert(rules, {x=-1, y=1,  z=0})
		table.insert(rules, {x=-1, y=-1, z=0})
		table.insert(rules, {x=0,  y=1,  z=1})
		table.insert(rules, {x=0,  y=-1, z=1})
		table.insert(rules, {x=0,  y=1,  z=-1})
		table.insert(rules, {x=0,  y=-1, z=-1})
	end
	if name=="movestone" then
		table.insert(rules, {x=0,  y=1,  z=-1})
		table.insert(rules, {x=0,  y=0,  z=-1})
		table.insert(rules, {x=0,  y=-1, z=-1})
		table.insert(rules, {x=0,  y=1,  z=1})
		table.insert(rules, {x=0,  y=-1, z=1})
		table.insert(rules, {x=0,  y=0,  z=1})
		table.insert(rules, {x=1,  y=0,  z=0})
		table.insert(rules, {x=1,  y=1,  z=0})
		table.insert(rules, {x=1,  y=-1, z=0})
		table.insert(rules, {x=-1, y=1,  z=0})
		table.insert(rules, {x=-1, y=-1, z=0})
		table.insert(rules, {x=-1, y=0,  z=0})
	end
	if name=="piston" then
		table.insert(rules, {x=0,  y=1,  z=0})
		table.insert(rules, {x=0,  y=-1,  z=0})
		table.insert(rules, {x=0,  y=1,  z=-1})
		table.insert(rules, {x=0,  y=0,  z=-1})
		table.insert(rules, {x=0,  y=-1, z=-1})
		table.insert(rules, {x=0,  y=1,  z=1})
		table.insert(rules, {x=0,  y=-1, z=1})
		table.insert(rules, {x=0,  y=0,  z=1})
		table.insert(rules, {x=1,  y=0,  z=0})
		table.insert(rules, {x=1,  y=1,  z=0})
		table.insert(rules, {x=1,  y=-1, z=0})
		table.insert(rules, {x=-1, y=1,  z=0})
		table.insert(rules, {x=-1, y=-1, z=0})
		table.insert(rules, {x=-1, y=0,  z=0})
	end
	if name=="pressureplate" then
		table.insert(rules, {x=0,  y=1,  z=-1})
		table.insert(rules, {x=0,  y=0,  z=-1})
		table.insert(rules, {x=0,  y=-1, z=-1})
		table.insert(rules, {x=0,  y=1,  z=1})
		table.insert(rules, {x=0,  y=-1, z=1})
		table.insert(rules, {x=0,  y=0,  z=1})
		table.insert(rules, {x=1,  y=0,  z=0})
		table.insert(rules, {x=1,  y=1,  z=0})
		table.insert(rules, {x=1,  y=-1, z=0})
		table.insert(rules, {x=-1, y=1,  z=0})
		table.insert(rules, {x=-1, y=-1, z=0})
		table.insert(rules, {x=-1, y=0,  z=0})
		table.insert(rules, {x=0, y=-1,  z=0})
		table.insert(rules, {x=0, y=1,  z=0})
	end
	if name=="mesecontorch_x+" then
		table.insert(rules, {x=1,  y=1,  z=0})
		table.insert(rules, {x=1,  y=0,  z=0})
		table.insert(rules, {x=1,  y=-1,  z=0})
	end
	if name=="mesecontorch_x-" then
		table.insert(rules, {x=-1,  y=1,  z=0})
		table.insert(rules, {x=-1,  y=0,  z=0})
		table.insert(rules, {x=-1,  y=-1,  z=0})
	end
	if name=="mesecontorch_z+" then
		table.insert(rules, {x=0,  y=1,  z=1})
		table.insert(rules, {x=0,  y=0,  z=1})
		table.insert(rules, {x=0,  y=-1,  z=1})
	end
	if name=="mesecontorch_z-" then
		table.insert(rules, {x=0,  y=1,  z=-1})
		table.insert(rules, {x=0,  y=0,  z=-1})
		table.insert(rules, {x=0,  y=-1,  z=-1})
	end
	if name=="mesecontorch_y+" then
		table.insert(rules, {x=-1,  y=1,  z=0})
		table.insert(rules, {x=-1,  y=1,  z=1})
		table.insert(rules, {x=-1,  y=1,  z=-1})

		table.insert(rules, {x=1,  y=1,  z=0})
		table.insert(rules, {x=1,  y=1,  z=1})
		table.insert(rules, {x=1,  y=1,  z=-1})

		table.insert(rules, {x=0,  y=1,  z=0})
		table.insert(rules, {x=0,  y=1,  z=1})
		table.insert(rules, {x=0,  y=1,  z=-1})
	end
	if name=="mesecontorch_y-" then
		table.insert(rules, {x=-1,  y=-1,  z=0})
		table.insert(rules, {x=-1,  y=-1,  z=1})
		table.insert(rules, {x=-1,  y=-1,  z=-1})

		table.insert(rules, {x=1,  y=-1,  z=0})
		table.insert(rules, {x=1,  y=-1,  z=1})
		table.insert(rules, {x=1,  y=-1,  z=-1})

		table.insert(rules, {x=0,  y=-1,  z=0})
		table.insert(rules, {x=0,  y=-1,  z=1})
		table.insert(rules, {x=0,  y=-1,  z=-1})
	end

	if name=="button_x+" or name=="button_x-"
	or name=="button_z-" or name=="button_z+" then --Is any button
table.insert(rules, {x=0,  y=0,  z=-1})
		table.insert(rules, {x=1,  y=0,  z=0})
		table.insert(rules, {x=-1, y=0,  z=0})
		table.insert(rules, {x=0,  y=0,  z=1})
		table.insert(rules, {x=1,  y=1,  z=0})
		table.insert(rules, {x=1,  y=-1, z=0})
		table.insert(rules, {x=-1, y=1,  z=0})
		table.insert(rules, {x=-1, y=-1, z=0})
		table.insert(rules, {x=0,  y=1,  z=1})
		table.insert(rules, {x=0,  y=-1, z=1})
		table.insert(rules, {x=0,  y=1,  z=-1})
		table.insert(rules, {x=0,  y=-1, z=-1})
		table.insert(rules, {x=0,  y=-1, z=0})
	end
	if name=="button_x+" then	
		table.insert(rules, {x=-2,  y=0,  z=0})	
	end
	if name=="button_x-" then	
		table.insert(rules, {x=2,  y=0,  z=0})	
	end
	if name=="button_z+" then	
		table.insert(rules, {x=0,  y=0,  z=-2})	
	end
	if name=="button_z-" then	
		table.insert(rules, {x=0,  y=0,  z=2})	
	end
	return rules
end






-- The POWER_PLANT

minetest.register_node("jeija:power_plant", {
	drawtype = "plantlike",
	visual_scale = 1,
	tile_images = {"jeija_power_plant.png"},
	inventory_image = "jeija_power_plant.png",
	paramtype = "light",
	walkable = false,
	material = minetest.digprop_leaveslike(0.2),
	light_source = LIGHT_MAX-9,
})

minetest.register_craft({
	output = 'node "jeija:power_plant" 1',
	recipe = {
		{'node "jeija:mesecon_off"'},
		{'node "jeija:mesecon_off"'},
		{'node "default:junglegrass"'},
	}
})

minetest.register_on_placenode(function(pos, newnode, placer)
	if newnode.name == "jeija:power_plant" then
		mesecon:receptor_on(pos)
	end
end)

minetest.register_on_dignode(
	function(pos, oldnode, digger)
		if oldnode.name == "jeija:power_plant" then
			mesecon:receptor_off(pos)
		end	
	end
)

mesecon:add_receptor_node("jeija:power_plant")


-- The BLINKY_PLANT

minetest.register_node("jeija:blinky_plant_off", {
	drawtype = "plantlike",
	visual_scale = 1,
	tile_images = {"jeija_blinky_plant_off.png"},
	inventory_image = "jeija_blinky_plant_off.png",
	paramtype = "light",
	walkable = false,
	material = minetest.digprop_leaveslike(0.2),
})

minetest.register_node("jeija:blinky_plant_on", {
	drawtype = "plantlike",
	visual_scale = 1,
	tile_images = {"jeija_blinky_plant_on.png"},
	inventory_image = "jeija_blinky_plant_off.png",
	paramtype = "light",
	walkable = false,
	material = minetest.digprop_leaveslike(0.2),
	dug_item='node "jeija:blinky_plant_off" 1',
	light_source = LIGHT_MAX-7,
})

minetest.register_craft({
	output = 'node "jeija:blinky_plant_off" 1',
	recipe = {
	{'','node "jeija:mesecon_off"',''},
	{'','node "jeija:mesecon_off"',''},
	{'node "default:junglegrass"','node "default:junglegrass"','node "default:junglegrass"'},
	}
})

minetest.register_abm(
	{nodenames = {"jeija:blinky_plant_off"},
	interval = BLINKY_PLANT_INTERVAL,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		--minetest.env:remove_node(pos)
		minetest.env:add_node(pos, {name="jeija:blinky_plant_on"})
		nodeupdate(pos)	
		mesecon:receptor_on(pos)
	end,
})

minetest.register_abm({
	nodenames = {"jeija:blinky_plant_on"},
	interval = BLINKY_PLANT_INTERVAL,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		--minetest.env:remove_node(pos)
		minetest.env:add_node(pos, {name="jeija:blinky_plant_off"})
		nodeupdate(pos)	
		mesecon:receptor_off(pos)
	end,
})

mesecon:add_receptor_node("jeija:blinky_plant_on")
mesecon:add_receptor_node_off("jeija:blinky_plant_off")

minetest.register_on_dignode(
	function(pos, oldnode, digger)
		if oldnode.name == "jeija:blinky_plant_on" then
			mesecon:receptor_off(pos)
		end
	end
)


-- Solar Panel

minetest.register_craftitem("jeija:silicon", {
	image = "jeija_silicon.png",
	on_place_on_ground = minetest.craftitem_place_item,
})


minetest.register_node("jeija:solar_panel", {
	drawtype = "raillike",
	tile_images = {"jeija_solar_panel.png"},
	inventory_image = "jeija_solar_panel.png",
	paramtype = "light",
	walkable = false,
	is_ground_content = true,
	selection_box = {
		type = "fixed",
	},
	furnace_burntime = 5,
	material = minetest.digprop_dirtlike(0.1),
})

minetest.register_craft({
	output = 'craft "jeija:silicon" 4',
	recipe = {
		{'node "default:sand"', 'node "default:sand"'},
		{'node "default:sand"', 'craft "default:steel_ingot"'},
	}
})

minetest.register_craft({
	output = 'node "jeija:solar_panel" 1',
	recipe = {
		{'craft "jeija:silicon"', 'craft "jeija:silicon"'},
		{'craft "jeija:silicon"', 'craft "jeija:silicon"'},
	}
})

minetest.register_abm(
	{nodenames = {"jeija:solar_panel"},
	interval = 0.1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local light = minetest.env:get_node_light(pos, nil)
		if light == nil then light = 0 end
		if light >= 13 then
			mesecon:receptor_on(pos)
		else
			mesecon:receptor_off(pos)
		end
	end,
})


-- MESELAMPS
minetest.register_node("jeija:meselamp_on", {
	drawtype = "torchlike",
	tile_images = {"jeija_meselamp_on_floor_on.png", "jeija_meselamp_on_ceiling_on.png", "jeija_meselamp_on.png"},
	inventory_image = "jeija_meselamp_on_floor_on.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	wall_mounted = false,
	light_source = LIGHT_MAX,
	selection_box = {
		type = "fixed",
		fixed = {-0.38, -0.5, -0.1, 0.38, -0.2, 0.1},
	},
	material = minetest.digprop_constanttime(0.1),
	dug_item='node "jeija:meselamp_off" 1',
})

minetest.register_node("jeija:meselamp_off", {
	drawtype = "torchlike",
	tile_images = {"jeija_meselamp_on_floor_off.png", "jeija_meselamp_on_ceiling_off.png", "jeija_meselamp_off.png"},
	inventory_image = "jeija_meselamp_on_floor_off.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	wall_mounted = false,
	selection_box = {
		type = "fixed",
		fixed = {-0.38, -0.5, -0.1, 0.38, -0.2, 0.1},
	},
	material = minetest.digprop_constanttime(0.1),
})

minetest.register_craft({
	output = 'node "jeija:meselamp_off" 1',
	recipe = {
		{'', 'node "default:glass"', ''},
		{'node "jeija:mesecon_off"', 'craft "default:steel_ingot"', 'node "jeija:mesecon_off"'},
		{'', 'node "default:glass"', ''},
	}
})


--PISTONS
--registration normal one:
minetest.register_node("jeija:piston_normal", {
	tile_images = {"jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_side.png", "jeija_piston_side.png", "jeija_piston_side.png", "jeija_piston_side.png"},
	inventory_image = minetest.inventorycube("jeija_piston_tb.png", "jeija_piston_side.png", "jeija_piston_side.png"),
	material = minetest.digprop_stonelike(0.5),
})

minetest.register_craft({
	output = 'node "jeija:piston_normal" 2',
	recipe = {
		{'node "default:wood"', 'node "default:wood"', 'node "default:wood"'},
		{'node "default:cobble"', 'craft "default:steel_ingot"', 'node "default:cobble"'},
		{'node "default:cobble"', 'node "jeija:mesecon_off"', 'node "default:cobble"'},
	}
})

--registration sticky one:
minetest.register_node("jeija:piston_sticky", {
	tile_images = {"jeija_piston_tb.png", "jeija_piston_tb.png", "jeija_piston_sticky_side.png", "jeija_piston_sticky_side.png", "jeija_piston_sticky_side.png", "jeija_piston_sticky_side.png"},
	inventory_image = minetest.inventorycube("jeija_piston_tb.png", "jeija_piston_sticky_side.png", "jeija_piston_sticky_side.png"),
	material = minetest.digprop_stonelike(0.5),
})

minetest.register_craft({
	output = 'node "jeija:piston_sticky" 1',
	recipe = {
		{'craft "jeija:glue"'},
		{'node "jeija:piston_normal"'},
	}
})

-- get push direction normal
function mesecon:piston_get_direction(pos)
	getactivated=0
	local direction = {x=0, y=0, z=0}
	local lpos={x=pos.x, y=pos.y, z=pos.z}
	local getactivated=0
	local rules=mesecon:get_rules("piston")

	getactivated=getactivated+mesecon:is_power_on(pos, rules[1].x, rules[1].y, rules[1].z)
	if getactivated>0 then direction.y=-1 return direction end
	getactivated=getactivated+mesecon:is_power_on(pos, rules[2].x, rules[2].y, rules[2].z)
	if getactivated>0 then direction.y=1 return direction end

	for k=3, 5 do
		getactivated=getactivated+mesecon:is_power_on(pos, rules[k].x, rules[k].y, rules[k].z)
	end
	if getactivated>0 then direction.z=1 return direction end

	for n=6, 8 do
		getactivated=getactivated+mesecon:is_power_on(pos, rules[n].x, rules[n].y, rules[n].z)
	end

	if getactivated>0 then direction.z=-1 return direction end

	for j=9, 11 do
		getactivated=getactivated+mesecon:is_power_on(pos, rules[j].x, rules[j].y, rules[j].z)
	end

	if getactivated>0 then direction.x=-1 return direction end

	for l=12, 14 do
		getactivated=getactivated+mesecon:is_power_on(pos, rules[l].x, rules[l].y, rules[l].z)
	end
	if getactivated>0 then direction.x=1 return direction end
	return direction
end

-- get pull/push direction sticky
function mesecon:sticky_piston_get_direction(pos)
	getactivated=0
	local direction = {x=0, y=0, z=0}
	local lpos={x=pos.x, y=pos.y, z=pos.z}
	local getactivated=0
	local rules=mesecon:get_rules("piston")

	getactivated=getactivated+mesecon:is_power_off(pos, rules[1].x, rules[1].y, rules[1].z)
	if getactivated>0 then direction.y=-1 return direction end
	getactivated=getactivated+mesecon:is_power_off(pos, rules[2].x, rules[2].y, rules[2].z)
	if getactivated>0 then direction.y=1 return direction end

	for k=3, 5 do
		getactivated=getactivated+mesecon:is_power_off(pos, rules[k].x, rules[k].y, rules[k].z)
	end
	if getactivated>0 then direction.z=1 return direction end

	for n=6, 8 do
		getactivated=getactivated+mesecon:is_power_off(pos, rules[n].x, rules[n].y, rules[n].z)
	end

	if getactivated>0 then direction.z=-1 return direction end

	for j=9, 11 do
		getactivated=getactivated+mesecon:is_power_off(pos, rules[j].x, rules[j].y, rules[j].z)
	end

	if getactivated>0 then direction.x=-1 return direction end

	for l=12, 14 do
		getactivated=getactivated+mesecon:is_power_off(pos, rules[l].x, rules[l].y, rules[l].z)
	end
	if getactivated>0 then direction.x=1 return direction end
	return direction
end

-- Push action
mesecon:register_on_signal_on(function (pos, node)
	if (node.name=="jeija:piston_normal" or node.name=="jeija:piston_sticky") then
		local direction=mesecon:piston_get_direction(pos)

		local checknode={}
		local checkpos={x=pos.x, y=pos.y, z=pos.z}
		repeat -- Check if it collides with a stopper
			checkpos={x=checkpos.x+direction.x, y=checkpos.y+direction.y, z=checkpos.z+direction.z}
			checknode=minetest.env:get_node(checkpos)
			if mesecon:is_mvps_stopper(checknode.name) then 
				return 
			end
		until checknode.name=="air"
		or checknode.name=="ignore" 
		or checknode.name=="default:water" 
		or checknode.name=="default:water_flowing" 

		local obj={}
		if node.name=="jeija:piston_normal" then
			obj=minetest.env:add_entity(pos, "jeija:piston_pusher_normal")
		elseif node.name=="jeija:piston_sticky" then
			obj=minetest.env:add_entity(pos, "jeija:piston_pusher_sticky")
		end
		
		if ENABLE_PISTON_ANIMATION==1 then		
			obj:setvelocity({x=direction.x*4, y=direction.y*4, z=direction.z*4})
		else
			obj:moveto({x=pos.x+direction.x, y=pos.y+direction.y, z=pos.z+direction.z}, false)
		end
		
		local np = {x=pos.x+direction.x, y=pos.y+direction.y, z=pos.z+direction.z}	
		local coln = minetest.env:get_node(np)
		
		or checknode.name=="ignore" 
		or checknode.name=="default:water" 
		or checknode.name=="default:water_flowing" 

		if coln.name ~= "air" and coln.name ~="water" then
			local thisp= {x=np.x, y=np.y, z=np.z}
			local thisnode=minetest.env:get_node(thisp)
			local nextnode={}
			minetest.env:remove_node(thisp)
			repeat
				thisp.x=thisp.x+direction.x
				thisp.y=thisp.y+direction.y
				thisp.z=thisp.z+direction.z
				nextnode=minetest.env:get_node(thisp)
				minetest.env:add_node(thisp, {name=thisnode.name})
				nodeupdate(thisp)
				thisnode=nextnode
			until thisnode.name=="air" 
			or thisnode.name=="ignore" 
			or thisnode.name=="default:water" 
			or thisnode.name=="default:water_flowing" 
		end
	end
end)

--Pull action (sticky only)
mesecon:register_on_signal_off(function (pos, node)
	if node.name=="jeija:piston_sticky" or node.name=="jeija:piston_normal" then
		local objs = minetest.env:get_objects_inside_radius(pos, 2)
		for k, obj in pairs(objs) do
			obj:remove()
		end

		if node.name=="jeija:piston_sticky" then
			local direction=mesecon:sticky_piston_get_direction(pos)
			local np = {x=pos.x+direction.x, y=pos.y+direction.y, z=pos.z+direction.z}	
			local coln = minetest.env:get_node(np)
			if coln.name == "air" or coln.name =="water" then
				local thisp= {x=np.x+direction.x, y=np.y+direction.y, z=np.z+direction.z}
				local thisnode=minetest.env:get_node(thisp)
				if thisnode.name~="air" and thisnode.name~="water" and not mesecon:is_mvps_stopper(thisnode.name) then
					local newpos={}
					local oldpos={}
					minetest.env:add_node(np, {name=thisnode.name})
					minetest.env:remove_node(thisp)
				end		
			end
		end
	end
end)

--Piston Animation
local PISTON_PUSHER_NORMAL={
	physical = false,
	visual = "sprite",
	textures = {"default_wood.png", "default_wood.png", "jeija_piston_pusher_normal.png", "jeija_piston_pusher_normal.png", "jeija_piston_pusher_normal.png", "jeija_piston_pusher_normal.png"},
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "cube",
	timer=0,
}

function PISTON_PUSHER_NORMAL:on_step(dtime)
	self.timer=self.timer+dtime
	if self.timer>=0.24 then
		self.object:setvelocity({x=0, y=0, z=0})
	end
end

local PISTON_PUSHER_STICKY={
	physical = false,
	visual = "sprite",
	textures = {"default_wood.png", "default_wood.png", "jeija_piston_pusher_sticky.png", "jeija_piston_pusher_sticky.png", "jeija_piston_pusher_sticky.png", "jeija_piston_pusher_sticky.png"},
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual = "cube",
	timer=0,
}

function PISTON_PUSHER_STICKY:on_step(dtime)
	self.timer=self.timer+dtime
	if self.timer>=0.24 then
		self.object:setvelocity({x=0, y=0, z=0})
	end
end

minetest.register_entity("jeija:piston_pusher_normal", PISTON_PUSHER_NORMAL)
minetest.register_entity("jeija:piston_pusher_sticky", PISTON_PUSHER_STICKY)

minetest.register_on_dignode(function(pos, node)
	if node.name=="jeija:piston_normal" or node.name=="jeija:piston_sticky" then
		local objs = minetest.env:get_objects_inside_radius(pos, 2)
		for k, obj in pairs(objs) do
			obj:remove()
		end
	end
end)

--GLUE
minetest.register_craftitem("jeija:glue", {
	image = "jeija_glue.png",
	on_place_on_ground = minetest.craftitem_place_item,
})

minetest.register_craft({
	output = 'craft "jeija:glue" 2',
	recipe = {
		{'node "default:junglegrass"', 'node "default:junglegrass"'},
		{'node "default:junglegrass"', 'node "default:junglegrass"'},
	}
})


-- HYDRO_TURBINE

minetest.register_node("jeija:hydro_turbine_off", {
	tile_images = {"jeija_hydro_turbine_off.png", "jeija_hydro_turbine_off.png", "jeija_hydro_turbine_off.png", "jeija_hydro_turbine_off.png", "jeija_hydro_turbine_off.png", "jeija_hydro_turbine_off.png"},
	inventory_image = minetest.inventorycube("jeija_hydro_turbine_off.png", "jeija_hydro_turbine_off.png", "jeija_hydro_turbine_off.png"),
	material = minetest.digprop_constanttime(0.5),
})

minetest.register_node("jeija:hydro_turbine_on", {
	tile_images = {"jeija_hydro_turbine_on.png", "jeija_hydro_turbine_on.png", "jeija_hydro_turbine_on.png", "jeija_hydro_turbine_on.png", "jeija_hydro_turbine_on.png", "jeija_hydro_turbine_on.png"},
	inventory_image = minetest.inventorycube("jeija_hydro_turbine_on.png", "jeija_hydro_turbine_on.png", "jeija_hydro_turbine_on.png"),
	dug_item = 'node "jeija:hydro_turbine_off" 1',
	material = minetest.digprop_constanttime(0.5),
})


minetest.register_abm({
nodenames = {"jeija:hydro_turbine_off"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local waterpos={x=pos.x, y=pos.y+1, z=pos.z}
		if minetest.env:get_node(waterpos).name=="default:water_flowing" then
			--minetest.env:remove_node(pos)
			minetest.env:add_node(pos, {name="jeija:hydro_turbine_on"})
			nodeupdate(pos)
			mesecon:receptor_on(pos)
		end
	end,
})

minetest.register_abm({
nodenames = {"jeija:hydro_turbine_on"},
	interval = 1,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local waterpos={x=pos.x, y=pos.y+1, z=pos.z}
		if minetest.env:get_node(waterpos).name~="default:water_flowing" then
			--minetest.env:remove_node(pos)
			minetest.env:add_node(pos, {name="jeija:hydro_turbine_off"})
			nodeupdate(pos)
			mesecon:receptor_off(pos)
		end
	end,
})

mesecon:add_receptor_node("jeija:hydro_turbine_on")
mesecon:add_receptor_node_off("jeija:hydro_turbine_off")

minetest.register_craft({
	output = 'node "jeija:hydro_turbine_off" 2',
	recipe = {
	{'','craft "default:stick"', ''},
	{'craft "default:stick"', 'craft "default:steel_ingot"', 'craft "default:stick"'},
	{'','craft "default:stick"', ''},
	}
})


-- MESECON_SWITCH

minetest.register_node("jeija:mesecon_switch_off", {
	tile_images = {"jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_off.png"},
	inventory_image = minetest.inventorycube("jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_off.png"),
	paramtype = "facedir_simple",
	material = minetest.digprop_constanttime(0.5),
})

minetest.register_node("jeija:mesecon_switch_on", {
	tile_images = {"jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_on.png"},
	inventory_image = minetest.inventorycube("jeija_mesecon_switch_side.png", "jeija_mesecon_switch_side.png", "jeija_mesecon_switch_on.png"),
	paramtype = "facedir_simple",
	material = minetest.digprop_constanttime(0.5),
	dug_item='node "jeija:mesecon_switch_off" 1',
})

mesecon:add_receptor_node("jeija:mesecon_switch_on")
mesecon:add_receptor_node_off("jeija:mesecon_switch_off")

minetest.register_on_punchnode(function(pos, node, puncher)
	if node.name == "jeija:mesecon_switch_on" then
		minetest.env:add_node(pos, {name="jeija:mesecon_switch_off", param1=node.param1})
		nodeupdate(pos)
		mesecon:receptor_off(pos)
	end
	if node.name == "jeija:mesecon_switch_off" then
		minetest.env:add_node(pos, {name="jeija:mesecon_switch_on", param1=node.param1})
		nodeupdate(pos)
		mesecon:receptor_on(pos)
	end
end)

minetest.register_on_dignode(
	function(pos, oldnode, digger)
		if oldnode.name == "jeija:mesecon_switch_on" then
			mesecon:receptor_off(pos)
		end
	end
)

minetest.register_craft({
	output = 'node "jeija:mesecon_switch_off" 2',
	recipe = {
		{'craft "default:steel_ingot"', 'node "default:cobble"', 'craft "default:steel_ingot"'},
		{'node "jeija:mesecon_off"','', 'node "jeija:mesecon_off"'},
	}
})

--Launch TNT

mesecon:register_on_signal_on(function(pos, node)
	if node.name=="experimental:tnt" then
		minetest.env:remove_node(pos)
		minetest.env:add_entity(pos, "experimental:tnt")
		nodeupdate(pos)
	end
end)

-- REMOVE_STONE

minetest.register_node("jeija:removestone", {
	tile_images = {"jeija_removestone.png"},
	inventory_image = minetest.inventorycube("jeija_removestone_inv.png"),
	material = minetest.digprop_stonelike(1.0),
})

minetest.register_craft({
	output = 'node "jeija:removestone" 4',
	recipe = {
		{'', 'node "default:cobble"',''},
		{'node "default:cobble"', 'node "jeija:mesecon_off"', 'node "default:cobble"'},
		{'', 'node "default:cobble"',''},
	}
})

mesecon:register_on_signal_on(function(pos, node)
	if node.name=="jeija:removestone" then
		minetest.env:remove_node(pos)
	end
end)


-- Include other files
dofile(minetest.get_modpath("jeija").."/movestone.lua")
dofile(minetest.get_modpath("jeija").."/button.lua")
dofile(minetest.get_modpath("jeija").."/torches.lua")
dofile(minetest.get_modpath("jeija").."/detector.lua")
dofile(minetest.get_modpath("jeija").."/pressureplates.lua")
dofile(minetest.get_modpath("jeija").."/wireless.lua")
--TEMPEREST's STUFF
if ENABLE_TEMPEREST==1 then
	dofile(minetest.get_modpath("jeija").."temperest.lua")
end

--INIT
mesecon:read_wlre_from_file()
--register stoppers for movestones/pistons
mesecon:register_mvps_stopper("default:chest")
mesecon:register_mvps_stopper("default:chest_locked")
mesecon:register_mvps_stopper("default:furnace")

print("[MESEcons] Loaded!")

--minetest.register_on_newplayer(function(player)
	--local i=1
	--while mesecon.wireless_receivers[i]~=nil do
	--	pos=mesecon.wireless_receivers[i].pos
	--	request=mesecon.wireless_receivers[i].requested_state
	--	inverting=mesecon.wireless_receivers[i].inverting
	--	if request==inverting then
	--		mesecon:receptor_off(pos)
	--	end
	--	if request~=inverting  then
	--		mesecon:receptor_on(pos)
	--	end
	--end
--end)
