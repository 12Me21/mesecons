minetest.register_node("mesecons_receiver:receiver_on", {
	tiles = {"default_wood.png"},
	groups = {dig_immediate = 3, mesecon = 3, not_in_creative_inventory = 1},
	drop = "mesecons:wire_00000000_off",
})

minetest.register_node("mesecons_receiver:receiver_off", {
	description = "You hacker you",
	tiles = {"default_stone.png"},
	groups = {dig_immediate = 3, mesecon = 3},
	drop = "mesecons:wire_00000000_off",
})

mesecon:add_rules("receiver_pos", {{x = 2,  y = 0, z = 0}})

mesecon:add_rules("receiver_pos_all", {
{x = 2,  y = 0, z = 0},
{x =-2,  y = 0, z = 0},
{x = 0,  y = 0, z = 2},
{x = 0,  y = 0, z =-2}})

mesecon:add_rules("mesecon_receiver", {
{x = 1, y = 0, z = 0},
{x = -2, y = 0, z = 0},})

mesecon:add_rules("mesecon_receiver_all", {
{x = 1, y = 0, z = 0},
{x =-2, y = 0, z = 0},
{x =-1, y = 0, z = 0},
{x = 2, y = 0, z = 0},
{x = 0, y = 0, z = 1},
{x = 0, y = 0, z =-2},
{x = 1, y = 0, z =-1},
{x =-2, y = 0, z = 2},})

function receiver_get_rules(param2)
	local rules = mesecon:get_rules("mesecon_receiver")
	if param2 == 2 then
		rules = mesecon:rotate_rules_left(rules)
	elseif param2 == 3 then
		rules = mesecon:rotate_rules_right(mesecon:rotate_rules_right(rules))
	elseif param2 == 0 then
		rules = mesecon:rotate_rules_right(rules)
	end
	return rules
end

mesecon:register_conductor("mesecons_receiver:receiver_on", "mesecons_receiver:receiver_off", mesecon:get_rules("mesecon_receiver_all"), receiver_get_rules)

function mesecon:receiver_get_pos_from_rcpt(pos)
	node = minetest.env:get_node(pos)
	local rules = mesecon:get_rules("receiver_pos")
	if node.param2 == 2 then
		rules = mesecon:rotate_rules_left(rules)
	elseif node.param2 == 3 then
		rules = mesecon:rotate_rules_right(mesecon:rotate_rules_right(rules))
	elseif node.param2 == 0 then
		rules = mesecon:rotate_rules_right(rules)
	end
	np = {
	x = pos.x + rules[1].x,
	y = pos.y + rules[1].y,
	z = pos.z + rules[1].z}
	return np
end

function mesecon:receiver_place(rcpt_pos)
	local node = minetest.env:get_node(rcpt_pos)
	pos = mesecon:receiver_get_pos_from_rcpt(rcpt_pos, node.param2)
	nn = minetest.env:get_node(pos)

	if string.find(nn.name, "mesecons:wire_") ~= nil then
		minetest.env:dig_node(pos)
		minetest.env:add_node(pos, {name = "mesecons_receiver:receiver_off", param2 = node.param2})
		mesecon:update_autoconnect(pos)
	end
end

function mesecon:receiver_remove(rcpt_pos)
	pos = mesecon:receiver_get_pos_from_rcpt(rcpt_pos)
	node = minetest.env:get_node(pos)

	if string.find(node.name, "mesecons_receiver:receiver_") ~=nil then
		minetest.env:dig_node(pos)
		minetest.env:place_node(pos, {name = "mesecons:wire_00000000_off"})
		mesecon:update_autoconnect(pos)
	end
end

minetest.register_on_placenode(function (pos, node)
	if minetest.get_item_group(node.name, "mesecon_needs_receiver") == 1 then
		mesecon:receiver_place(pos)
	end
end)

minetest.register_on_dignode(function(pos, node)
	if minetest.get_item_group(node.name, "mesecon_needs_receiver") == 1 then
		mesecon:receiver_remove(pos)
	end
end)

minetest.register_on_placenode(function (pos, node)
	if string.find(node.name, "mesecons:wire_") ~=nil then
		rules = mesecon:get_rules("receiver_pos_all")
		local i = 1
		while rules[i] ~= nil do
			np = {
			x = pos.x + rules[i].x,
			y = pos.y + rules[i].y,
			z = pos.z + rules[i].z}
			if minetest.get_item_group(minetest.env:get_node(np).name, "mesecon_needs_receiver") == 1 then
				mesecon:receiver_place(np)
			end
			i = i + 1
		end
	end
end)
