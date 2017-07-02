
-- Engage Enemies
function fai_engage(id)
	
	local x1=player(id,"x")
	local y1=player(id,"y")

	-- ############################################################ Prepare Neat Inputs
	local lineOnTarget = 0
	local nearTargetDirection = 0
	local nearTargetAngle = 360
	local targetDistance = 0
	local distance = 0
	local reloading = 0
	local enemyOffAngle = 0
	local freelineEnemies = 0
	if player(id,"reloading") then
		reloading = 1
	end
	vai_target[id]=0
	
	if player(id,"ai_flash")==0 then
		--Look for a Target in View and check if player aims at a target in view
		local livingplayers=player(0,"tableliving")
		for _,pid in pairs(livingplayers) do
			if player(pid,"exists") then
				if player(pid,"health")>0 and player(pid,"team")>0 and fai_enemies(id,pid) then

					local x2=player(pid,"x")
					local y2=player(pid,"y")

					-- In Range?
					if math.abs(x1-x2)<350 and math.abs(y1-y2)<235 then
						if ai_freeline(id,x2,y2) then
							freelineEnemies = freelineEnemies + 1
						end
						local angle = fai_angledelta(tonumber(player(id,"rot")),fai_angleto(x1,y1,x2,y2))
						if math.abs(angle)<=nearTargetAngle or vai_target[id]==0 then
							vai_target[id]=pid
							nearTargetAngle = math.abs(angle)
							--nearTargetDirection = angle/180
							if angle>0 then
								nearTargetDirection = 1
							elseif angle<0 then
								nearTargetDirection = -1
							end
							if angle>0 then
								nearTargetDirection = 1
							end
						end

					end
				end
			end
		end
		if vai_target[id]>0 then
			if freelineEnemies==0 then
				vai_target[id]=0

			else
				vai_aim_off_angle[id]=nearTargetAngle
				local x2=player(vai_target[id],"x")
				local y2=player(vai_target[id],"y")
				--Calculate the distane to the Target
				local distx = math.abs(x1 - x2)
				local disty = math.abs(y1 - y2)
				distance = math.sqrt((distx * distx) + (disty * disty))
				targetDistance = math.sqrt((distx * distx) + (disty * disty))
				-- aims at target and freeline?
				if ai_freeline(id,x2,y2) and math.abs(fai_angledelta(tonumber(player(id,"rot")),fai_angleto(x1,y1,x2,y2)))<5 or distance<30 then
					lineOnTarget = 1
				end


				--enemy off angle
				enemyOffAngle = fai_angledelta(tonumber(player(vai_target[id],"rot")),fai_angleto(x2,y2,x1,y1))/180
			end
		end
	else
		--Flashed!
		lineOnTarget = -1
	end

	if vai_target[id]>0 or player(id,"ai_flash")>0 then
		-- ############################################################ Set inputs
		local inputs = {}
		inputs[1] = lineOnTarget
		inputs[2] = nearTargetDirection
		inputs[3] = targetDistance
		inputs[4] = enemyOffAngle

		if vai_set_debug then
			ai_debug(id,"f:"..vai_fitness[id] .. "l:" .. inputs[1] .. "r:" .. inputs[2] .. "d:" .. inputs[3])
		end

		-- ############################################################ Calculate Outputs
		local outputs = {}
		outputs = fai_neat_evaluate(vai_neat, id, inputs)

		-- ############################################################ Perform and Evaluate
		-- Switch to Fight Mode
		if vai_mode[id]~=4 and vai_mode[id]~=5 then
			vai_timer[id]=math.random(25,100)
			vai_smode[id]=math.random(0,360)
			vai_mode[id]=4
		end

		--Attack
		if outputs[1]>0.5 then
			--Normal Attack
			ai_iattack(id)
			if player(id,"ai_flash")==0 then
				if (vai_aim_off_angle[id]>5 and distance>30) or not ai_freeline(id,player(vai_target[id],"x"),player(vai_target[id],"y")) then
					--BAD BEHAVIOR -- Wasting Ammo
					fai_next_evaluation(id)
				else
					vai_fitness[id]= vai_fitness[id] + 100
				end
			end
			vai_engage_timer[id]=vai_neat_engage_timeout
		elseif outputs[1]<0.5 then
			--Special Attack
			--ai_attack(id,1)
		end

		--Aim
		local turnspeed = 20
		if turnspeed>nearTargetAngle then
			turnspeed=nearTargetAngle
		end
		vai_aim_rotation[id]= vai_aim_rotation[id] + outputs[2]*turnspeed
		vai_aim_distance[id]=outputs[3] * 315
		local aimx = x1 + vai_aim_distance[id] * math.cos(math.rad(vai_aim_rotation[id]))
		local aimy = y1 + vai_aim_distance[id] * math.sin(math.rad(vai_aim_rotation[id]))

		ai_aim(id,aimx,aimy)

		--Move
		local relativeMoveX = outputs[4]
		local relativeMoveY = outputs[5]
		local relativeMoveAngle = fai_angleto(0,0,relativeMoveX,relativeMoveY)
		local moveAngle = relativeMoveAngle
		if player(id,"ai_flash")==0 then
			if ai_freeline(id,player(vai_target[id],"x"),player(vai_target[id],"y")) then
				moveAngle = relativeMoveAngle + fai_angleto(player(vai_target[id],"x"),player(vai_target[id],"y"),x1,y1)
				if not (relativeMoveX==0 and relativeMoveY==0) then
					ai_move(id,moveAngle)
				end
				

				vai_engage_timer[id] = vai_engage_timer[id] - 1
			else
				if ai_goto(id,player(vai_target[id],"tilex"),player(vai_target[id],"tiley"))~=2 then
					vai_mode[id]=0
				end
			end
		else
			if not (relativeMoveX==0 and relativeMoveY==0) then
				ai_move(id,moveAngle)
			end
			
		end

		
		--vai_fitness[id]= vai_fitness[id] + 1
		if vai_engage_timer[id] <= 0 then
			--BAD BEHAVIOR -- Taking to long to Engage
			fai_next_evaluation(id)
		end
	else
		-- No Combat reset timer for next Combat
		vai_engage_timer[id]=vai_neat_engage_timeout
		--switch to knife
		ai_selectweapon(id, 50)
	end
end

function fai_next_evaluation(id)
	vai_fitness[id] = vai_fitness[id] + ((player(id,"score") - vai_start_score[id]) * 500) + 180 - vai_aim_off_angle[id] - vai_neat_engage_timeout -1
	fai_neat_rate(vai_neat, id,vai_fitness[id])
	print("Fitness: " .. vai_fitness[id] .. " next evaluation...")
	--reset values
	vai_engage_timer[id]=vai_neat_engage_timeout
	vai_start_score[id]= player(id,"score")
	vai_fitness[id]= 0
	--msg("Generation: " .. vai_neat.pool.generation .. "Max Fitness: " .. math.floor(vai_neat.pool.maxFitness) .. "Genome Checked: " .. vai_neat.lastGenomeSelected)
end