--[[
	Map Sweepers - Co-op NPC Shooter Gamemode for Garry's Mod by "Octantis Addons" (consisting of MerekiDor & JonahSoldier)
    Copyright (C) 2025  MerekiDor

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

	See the full GNU GPL v3 in the LICENSE file.
	Contact E-Mail: merekidorian@gmail.com
--]]
AddCSLuaFile()

--todo: Vehicle system issue, player's view will be flipped when leaving a vehicle if the vehicle is flipped.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "J Corp JAPC0 "
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

if SERVER then
	ENT.vectorOffsets = {
		{ -58, -50 },
		{ 65, -50 },

		{ -58, 50 },
		{ 65, 50 }
	}
end

function ENT:Initialize()
	self:SetCollisionGroup(COLLISION_GROUP_VEHICLE)
	
	if SERVER then
		self:SetModel("models/jcms/jcorp_apc.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:GetPhysicsObject():Wake()
		self:StartMotionController()
		
		self.soundEngine = CreateSound(self, "plats/elevator_move_loop1.wav")
		self.soundEngine:Play()
		self.soundEngine:ChangePitch(82)
		self.soundTurbo = CreateSound(self, "vehicles/airboat/fan_motor_fullthrottle_loop1.wav")
		self.soundTurbo:Play()
		self.soundTurbo:ChangePitch(12)
		self.soundWater = CreateSound(self, "vehicles/airboat/pontoon_fast_water_loop1.wav")
		
		self:SetMaxHealth(2000)
		self:SetHealth(2000)

		self:AddEFlags(EFL_DONTBLOCKLOS)

		self.nextInteract = 0
		self:SetUseType(SIMPLE_USE)

		self.delayedForces = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "HealthFraction")
	self:NetworkVar("Float", 1, "ShieldPower")
	self:NetworkVar("Bool", 0, "IsDestroyed")
	self:NetworkVar("Bool", 1, "ShieldReady")
	self:NetworkVar("Bool", 2, "ShieldActive")
	if SERVER then
		self:SetHealthFraction(1)
		self:SetIsDestroyed(false)
		self:SetShieldReady(true)
		self:SetShieldPower(1)
	end
end

if SERVER then
	ENT.HoverDistance = 92
	ENT.Speed = 485
	ENT.SpeedTurbo = 690
	ENT.TurnSpeed = 130
	ENT.TurnSpeedTurbo = 110
	ENT.SpeedLooseMul = 0.772
	ENT.MoveTurnSpeedMul = 0.9
	ENT.MaxDampForce = 3000
	ENT.ShieldDuration = 8
	ENT.ShieldRechargeTime = 15
	
	function ENT:Think()
		local selfTbl = self:GetTable()
		if selfTbl.jcms_destroyed then
			if selfTbl.GetShieldActive(self) then
				selfTbl.SetShieldActive(self, false)
				selfTbl.SetShieldPower(self, 0)
			end

			if self.soundEngine then
				self.soundEngine:Stop()
				self.soundEngine = nil
			end

			if self.soundTurbo then
				self.soundTurbo:Stop()
				self.soundTurbo = nil
			end
			
			if self.soundWater then
				self.soundWater:Stop()
				self.soundWater = nil
			end
		else
			self:GetPhysicsObject():Wake()
			local speed = self:GetVelocity():Length()
			if selfTbl.soundEngine then
				selfTbl.soundEngine:ChangePitch(75 + speed/300*20, 0.1)
			end

			if selfTbl.soundTurbo then
				selfTbl.soundTurbo:ChangePitch(32 + speed/10, 0.1)
			end
			
			if selfTbl.soundWater then
				if selfTbl.onWater then
					if not selfTbl.soundWater:IsPlaying() then
						selfTbl.soundWater:Play()
						selfTbl.soundWater:ChangeVolume(0)
					end
					
					selfTbl.soundWater:ChangeVolume(1, 0.1)
				else
					if selfTbl.soundWater:IsPlaying() and selfTbl.soundWater:GetVolume() <= 0 then
						selfTbl.soundWater:Stop()
					else
						selfTbl.soundWater:ChangeVolume(0, 0.1)
					end
				end
				
				selfTbl.soundWater:ChangePitch(math.Clamp(speed/300*90 + 90, 0, 125), 0.1)
			end
			
			local driver = selfTbl.GetDriver(self)
			if IsValid(driver) then
				local pos = self:GetPos()
				pos.z = pos.z - 48
				driver:SetPos(pos)
				
				local wep = driver:GetActiveWeapon()
				if IsValid(wep) then
					wep:SetNextPrimaryFire( CurTime() + 1 )
					wep:SetNextSecondaryFire( CurTime() + 1 )
				end
			end

			local t = CurTime()
			local dt = 0.1
			if not selfTbl.nextShieldThink or t > selfTbl.nextShieldThink then
				local power = selfTbl.GetShieldPower(self)
				if selfTbl.GetShieldActive(self) then
					selfTbl.SetShieldPower(self, math.max(0, power - dt/selfTbl.ShieldDuration))
					if selfTbl.GetShieldPower(self) == 0 then
						selfTbl.SetShieldActive(self, false)
						selfTbl.SetShieldReady(self, false)
						self:EmitSound("ambient/energy/powerdown2.wav", 120, 160, 1)
					end
				elseif not selfTbl.GetShieldReady(self) then
					selfTbl.SetShieldPower(self, math.min(1, power + dt/selfTbl.ShieldRechargeTime))
					if selfTbl.GetShieldPower(self) == 1 then
						selfTbl.SetShieldReady(self, true)
					end
				end
				
				selfTbl.nextShieldThink = t + dt
			end
		end
	end
	
	function ENT:OnRemove()
		self:SetDriver()
		self:StopMotionController()

		if self.soundEngine then
			self.soundEngine:Stop()
		end

		if self.soundTurbo then
			self.soundTurbo:Stop()
		end

		if self.soundWater then
			self.soundWater:Stop()
		end
	end
	
	function ENT:PhysicsCollide(data, phys)
		local speed = data.OurOldVelocity:Length()

		PrintTable(data)

		local shieldOn = self:GetShieldActive()
		
		if speed > 120 and data.HitEntity:Health() > 0 then
			local dmg = DamageInfo()
			dmg:SetDamage(math.sqrt(speed) / 10 + 5)
			dmg:SetAttacker(self:GetDriver() or self)
			dmg:SetInflictor(self)
			dmg:SetDamageType(bit.bor(DMG_CRUSH, DMG_VEHICLE))
			dmg:SetReportedPosition(self:GetPos())
			dmg:SetDamagePosition(data.HitPos)
			data.HitEntity:TakeDamageInfo(dmg)
		end
		
		if speed > 700 then
			if shieldOn then
				self:EmitSound("weapons/physcannon/energy_bounce2.wav", 100, 113, 1)
			else
				self:EmitSound("ATV_rollover")
			end
			self:TakeDamage(math.Remap(speed, 700, 1400, 35, 260), data.HitEntity, data.HitEntity)
		elseif speed > 300 then
			if shieldOn then
				self:EmitSound("weapons/physcannon/energy_bounce1.wav", 100, 107, 1)
			else
				self:EmitSound("ATV_impact_heavy")
			end
			self:TakeDamage(math.Remap(speed, 300, 700, 5, 35), data.HitEntity, data.HitEntity)
		elseif not shieldOn then
			self:EmitSound("ATV_impact_medium")
		end
	end

	function ENT:PhysicsSimulate(phys, dt)
		if self.jcms_destroyed then
			if IsValid(self:GetDriver()) then
				self:SetDriver()
			end
			return
		end

		local mass = phys:GetMass()
		local mypos = self:WorldSpaceCenter()
		local myang = phys:GetAngles()

		local myfwd = myang:Forward()
		local myright = myang:Right()
		local myup = myang:Up()
		
		local hoverDistance = self.HoverDistance
		local mins, maxs = Vector(-16, -16, -6), Vector(16, 16, 4)
		
		local driver = self:GetDriver()
		local trFilter = { self }
		if IsValid(driver) then 
			table.insert(trFilter, driver)
		end
		
		phys:Wake()

		-- Traces {{{
			self.onWater = false

			local vecAngularSum = Vector(0, 0, 0)
			local vecLinearSum = Vector(0, 0, 0)

			local vectorNumber = #self.vectorOffsets
			for i=1, vectorNumber do
				local tr1pos = mypos + myang:Forward() * self.vectorOffsets[i][1] + myang:Right() * self.vectorOffsets[i][2]
				local tr1 = util.TraceHull {
					start = tr1pos, endpos = tr1pos + myup*(-hoverDistance),
					mins = mins, maxs = maxs, mask = bit.bor(MASK_WATER, MASK_DEADSOLID),
					filter = trFilter
				}

				self.onWater = self.onWater or tr1.MatType == MAT_SLOSH
				
				local force = 0
				if tr1.Fraction < 1 then
					force = (1 - tr1.Fraction^0.5) * mass * 5
				end

				if force > self.delayedForces[i] then
					self.delayedForces[i] = ( self.delayedForces[i] * 2 + force ) / 3
				else
					self.delayedForces[i] = self.delayedForces[i] * 0.3
				end

				debugoverlay.SweptBox(tr1pos, tr1.HitPos, mins, maxs, Angle(0,0,0), 0.1, Color(255, 0, 0))

				if self.delayedForces[i] > 0 then
					local lImp, aImp = phys:CalculateForceOffset(myup * ( self.delayedForces[i] / vectorNumber ) , tr1pos)

					vecAngularSum:Add(aImp)
					vecLinearSum:Add(lImp)
				end
			end
		-- }}}

		-- Damp {{{
			local myvel = phys:GetVelocity()
			local xyDamp = Vector( -myvel:Dot(myfwd), myvel:Dot(myright) * 1.5, 0 )
			
			local myangvel = phys:GetAngleVelocity()

			myangvel:Negate()
			myangvel:Mul(2)
			myangvel.x = myangvel.x * 2
			local angDamp = myangvel
		-- }}}

		-- Controls {{{
			local ctrlFwd = 0
			local ctrlSpin = 0
			local ctrlTurbo = 0
			local ctrlDrift = 0
			
			if driver then
				if driver:KeyDown(IN_USE) and CurTime() > self.nextInteract then
					self:SetDriver()
					self.nextInteract = CurTime() + 1
				else
					if driver:KeyDown(IN_FORWARD) then
						if driver:KeyDown(IN_SPEED) then
							ctrlTurbo = 1
						end
						ctrlFwd = 1
					elseif driver:KeyDown(IN_BACK) then
						ctrlFwd = -1
					elseif driver:KeyDown(IN_SPEED) then
						ctrlDrift = 1
					end
					
					if driver:KeyDown(IN_MOVELEFT) then
						ctrlSpin = -1
						ctrlFwd = ctrlFwd * self.MoveTurnSpeedMul
					elseif driver:KeyDown(IN_MOVERIGHT) then
						ctrlSpin = 1
						ctrlFwd = ctrlFwd * self.MoveTurnSpeedMul
					end

					if self.attacking1 then
						if self:GetShieldReady() then
							self:SetShieldReady(false)
							self:SetShieldActive(true)
							self:SetShieldPower(1)
							self:EmitSound("ambient/machines/thumper_startup1.wav", 120, 200, 1)
						end
					end
				end
				
				if looseTraction then
					ctrlFwd = ctrlFwd * self.SpeedLooseMul
				end
			end

			if math.abs(ctrlFwd) < 0.1 then
				xyDamp.x = xyDamp.x * Lerp(ctrlDrift, 0.8, 0)
				xyDamp.y = xyDamp.y * Lerp(ctrlDrift, 2.1, 3)
			end

			xyDamp.x = math.Clamp(xyDamp.x, -500, 500)
			xyDamp.y = math.Clamp(xyDamp.y, -500, 500)
		-- }}}

		-- Final {{{
			local vecAngular = Vector(0, 0, 0)
			vecAngular:Add(vecAngularSum)
			vecAngular:Add(angDamp)
			vecAngular.z = vecAngular.z - ctrlSpin * Lerp(ctrlTurbo, self.TurnSpeed, self.TurnSpeedTurbo)

			local vecLinear = Vector(0, 0, 0)
			vecLinear:Add(vecLinearSum)
			vecLinear:Add(xyDamp)
			vecLinear.x = vecLinear.x + ctrlFwd * Lerp(ctrlTurbo, self.Speed, self.SpeedTurbo)

			return vecAngular, vecLinear, SIM_LOCAL_ACCELERATION
		-- }}}
	end
	
	function ENT:Use(activator)
		if (not self.jcms_destroyed) and (CurTime() > self.nextInteract) and (not (IsValid(self.driver) and self.driver:IsPlayer())) then
			self:SetDriver(activator)
			self.nextInteract = CurTime() + 1
		end
	end

	function ENT:GetExitPos()
		-- Hull traces
		local filter = { self, self.driver }
		local angle = self:GetAngles()
		local pos = self:WorldSpaceCenter()
		for i=0, 3 do
			local a = math.pi/2*i
			local cos, sin = math.cos(a), math.sin(a)
			
			local v = pos + angle:Right()*(cos*120) + angle:Forward()*(sin*150)
			local tr = util.TraceHull {
				start = pos, endpos = v, filter = filter, mins = self.driver:OBBMins(), maxs = self.driver:OBBMaxs()
			}

			if tr.Fraction > 0.85 then
				return tr.HitPos
			end
		end

		local uptrace = util.TraceHull {
			start = pos, endpos = pos + Vector(0, 0, 62), filter = filter, mins = self.driver:OBBMins(), maxs = self.driver:OBBMaxs()
		}

		if uptrace.Fraction > 0.5 then
			return uptrace.HitPos
		else
			uptrace = util.TraceHull {
				start = pos, endpos = pos + Vector(0, 0, -100), filter = filter, mins = self.driver:OBBMins(), maxs = self.driver:OBBMaxs()
			}
			if uptrace.Fraction > 0.5 then
				return uptrace.HitPos
			end
		end

		local area = navmesh.GetNearestNavArea(pos)
		if IsValid(area) then
			return area:GetCenter()
		end

		return pos
	end
	
	function ENT:SetDriver(ply)
		-- Carjacking
		if IsValid(self.driver) and self.driver:IsPlayer() then
			self.driver:SetMoveType(MOVETYPE_WALK)
			self.driver:DrawViewModel(true)
			self.driver:DrawWorldModel(true)
			self.driver:SetNoDraw(false)
			self.driver:SetNWEntity("jcms_vehicle", NULL)
			
			if ply == nil then
				self.driver:SetPos(self:GetExitPos())
			end

			local ea = self.driver:EyeAngles()
			ea.r = 0
			self.driver:SetEyeAngles(ea)

			self.driver = nil
		end
		
		if IsValid(ply) and ply:IsPlayer() and ply:GetNWEntity("jcms_vehicle") == NULL then
			self.driver = ply
			ply:SetMoveType( MOVETYPE_NOCLIP )
			ply:DrawViewModel(false)
			ply:DrawWorldModel(false)
			ply:SetNoDraw(true)
			ply:SetNWEntity("jcms_vehicle", self)
			ply:SetEyeAngles(self:GetAngles())
		end
	end
	
	function ENT:GetDriver()
		if IsValid(self.driver) then
			return self.driver
		else
			self.driver = nil
		end
	end
	
	function ENT:OnTakeDamage(dmg)
		local dmgAmount = dmg:GetDamage()
		if self:GetShieldActive() then
			jcms_util_shieldDamageEffect(dmg, dmgAmount)
			return
		end

		if self:Health() > 0 then
			local inflictor, attacker = dmg:GetInflictor(), dmg:GetAttacker()
			if IsValid(inflictor) and jcms.util_IsStunstick(inflictor) and jcms.team_JCorp(attacker) then
				jcms.util_PerformRepairs(self, attacker, 20)
				self:SetHealthFraction(self:Health()/self:GetMaxHealth())
				return 0
			end
		end

		if bit.band(dmg:GetDamageType(), bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_BLAST, DMG_ENERGYBEAM)) > 0 then
			dmgAmount = math.max(dmgAmount*0.66 - 4, 0.01)
		elseif bit.band(dmg:GetDamageType(), DMG_CRUSH) > 0 then
			dmgAmount = dmgAmount*1.13
		end
		
		self:TakePhysicsDamage(dmg)
		if self.jcms_destroyed then return end
		
		local difficultyMultiplier = IsValid(self:GetDriver()) and (1 / (math.max(jcms.runprogress_GetDifficulty(), 1)^0.75)) or 1
		self:SetHealth( self:Health() - dmgAmount*difficultyMultiplier )
		self:SetHealthFraction(math.max(0, self:Health() / self:GetMaxHealth()))
		dmg:SetDamage(dmgAmount)

		if self:Health() <= 0 then
			self.jcms_destroyed = true
			self:SetIsDestroyed(true)

			local ed = EffectData()
			ed:SetMagnitude(1.6)
			ed:SetOrigin(self:WorldSpaceCenter())
			ed:SetRadius(260)
			ed:SetNormal(self:GetAngles():Up())
			ed:SetFlags(1)
			util.Effect("jcms_blast", ed)
			util.Effect("Explosion", ed)

			self:SetMaterial("models/jcms/jcorp_apc_destroyed")
		end
	end
	
	function ENT:RedirectDamage(driver, dmg)
		dmg:ScaleDamage(0)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
		if not self:GetIsDestroyed() and FrameTime() > 0 and jcms.performanceEstimate >= 30 then
			local e = self.emitter
			if not e then
				e = ParticleEmitter(self:WorldSpaceCenter())
				self.emitter = e
			end

			local exhaustPos = self:WorldSpaceCenter()
			local ang = self:GetAngles()
			local fwd, up, right = ang:Forward(), ang:Up(), ang:Right()
			fwd:Mul(-108)
			up:Mul(-52)
			exhaustPos:Add(fwd)
			exhaustPos:Add(up)
			right:Mul(FrameNumber()%2==0 and 30 or -30)
			exhaustPos:Add(right)
			e:SetPos(exhaustPos)

			local speed = self:GetVelocity():Length()

			local p = e:Add("particle/smokesprites_0001", exhaustPos)
			if p then
				local fadefactor = math.sqrt(speed/300)
				p:SetVelocity(ang:Forward()*-128)
				p:SetAirResistance(150)
				
				p:SetStartAlpha(255-fadefactor*100)
				p:SetEndAlpha(0)

				p:SetStartSize(fadefactor*8)
				p:SetEndSize(32+fadefactor*48)

				p:SetRoll(math.random()*360)
				p:SetRollDelta(math.random()*5 - 2.5)

				p:SetDieTime(fadefactor+0.15)
				p:SetColor(32, 32, 32)
			end
		end
	end

	ENT.mat_shield = Material("effects/combineshield/comshieldwall")
	ENT.scalematrix = Matrix()
	ENT.scalematrix:Scale(Vector(1.05, 1.05, 1.08))

	function ENT:DrawTranslucent()
		if self:GetShieldActive() then
			local shieldPower = self:GetShieldPower()
			local shieldPowerExp = shieldPower*shieldPower*shieldPower*shieldPower

			self:RemoveAllDecals()

			self:EnableMatrix("RenderMultiply", self.scalematrix)
			render.SetColorModulation(0, Lerp(shieldPowerExp, 0, 400), Lerp(shieldPowerExp, 10, 700))
			render.ModelMaterialOverride(self.mat_shield)
				self:SetupBones()
				self:DrawModel()
			render.ModelMaterialOverride()
			render.SetColorModulation(1, 1, 1)
			self:DisableMatrix("RenderMultiply")
		end
	end

	function ENT:OnRemove()
		if self.emitter then
			self.emitter:Finish()
		end
	end

	function ENT:DrawHUDBottom()
		local healthWidth = 1200
		local healthFrac = math.Clamp(self:GetHealthFraction(), 0, 1)
		local off = 6

		local shieldActive = self:GetShieldActive()
		local shieldFrac = math.Clamp(self:GetShieldPower(), 0, 1)

		surface.SetDrawColor(jcms.color_dark_alt)
		surface.DrawRect(-healthWidth/2 + 200, -114-64, healthWidth - 128, 32)
		if not shieldActive then
			surface.SetDrawColor(jcms.color_dark)
		end
		surface.DrawRect(-healthWidth/2, -114, healthWidth, 32)

		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			surface.SetDrawColor(jcms.color_pulsing)
			surface.DrawRect(-400, -64, 800, 4)
			surface.DrawRect(-256, -64+16, 512, 6)

			surface.SetDrawColor(jcms.color_bright_alt)
			if self:GetShieldReady() or shieldActive then
				surface.DrawRect(-healthWidth/2 + 200, -114-off-64, (healthWidth-128)*shieldFrac, 32)
			else
				jcms.hud_DrawStripedRect(-healthWidth/2 + 200, -114-off-64, (healthWidth-128)*shieldFrac, 16, 128, CurTime()*-128)
			end

			if not shieldActive then
				surface.SetDrawColor(healthFrac < 0.4 and jcms.color_alert or jcms.color_bright)
			end
			jcms.hud_DrawStripedRect(-healthWidth/2, -114-off+2, healthWidth, 32-4, 128, shieldActive and CurTime()*-32 or 0)
			surface.DrawRect(-healthWidth/2, -114-off, healthWidth*healthFrac, 32)
		render.OverrideBlend(false)
	end
	
	function ENT:CalcViewDriver(ply, origin, angles, fov, znear, zfar)
		local mypos = self:GetPos()
		local myang = self:GetAngles()
		local speed = self:GetVelocity():Length()
		
		origin = mypos + myang:Up()*24 + angles:Forward() * -210 + angles:Up() * 32
		angles.roll = math.AngleDifference(angles.roll, -myang.roll)*0.25
		
		return {
			origin = origin,
			angles = angles,
			fov = fov,
			
			znear = znear,
			zfar = zfar,
			
			drawviewer = false
		}
	end
end
