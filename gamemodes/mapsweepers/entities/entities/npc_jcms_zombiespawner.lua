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

ENT.Type = "ai"
ENT.Base = "base_anim"
ENT.PrintName = "Zombie Spawner"
ENT.Author = "Octantis Addons"
ENT.Category = "Map Sweepers"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

if SERVER then 
	function ENT:Initialize()
		self:SetModel("models/jcms/zombiespawner.mdl")

		self:SetHullType(HULL_LARGE)
		self:SetHullSizeNormal()
		self:SetSolid(SOLID_OBB)

		self:SetMaxHealth(750)
		self:SetHealth(750)
		self.nextSpawn = CurTime() + 5
		self.spawnedNPCs = {}

		self.jcms_flinchProgress = 0
		self.jcms_ignoreStraggling = true

		self:SetSequence("idle")
		self:SetCycle(math.random())
		self:SetBloodColor(BLOOD_COLOR_ANTLION)

		self:SetAngles( Angle(math.Rand(-2, 2), math.random()*360, math.Rand(-2, 2)) )
		
		self:SetNWString("jcms_boss", "zombie_spawner")
	end

	function ENT:OnTakeDamage(dmgInfo)
		local dmg = dmgInfo:GetDamage()

		if self.dying then
			return
		end

		if dmg > 0 then
			if bit.band( dmgInfo:GetDamageType(), DMG_BLAST ) > 0 then
				dmgInfo:ScaleDamage(1.5)
			end

			self.jcms_flinchProgress = self.jcms_flinchProgress + dmg 
			self:SetHealth(self:Health() - dmg)
			
			if self.jcms_flinchProgress > 25 then

				self:SetSequence( math.random() < 0.5 and "flinch02" or "flinch01" )
				local dur = self:SequenceDuration()
				timer.Simple(dur, function()
					if IsValid(self) and self:GetSequenceName( self:GetSequence() ):match("flinch") then
						self:SetSequence("idle")
						self:SetCycle(0)
					end
				end)

				self.jcms_flinchProgress = 0
			end
		end

		if self:Health() <= 0 then
			self.dying = true
			self:SetSequence("death")
			self:SetCycle(0)
			hook.Call("OnNPCKilled", GAMEMODE, self, dmgInfo:GetAttacker(), dmgInfo:GetInflictor())

			timer.Simple(1, function()
				if IsValid(self) then
					self:Remove()
				end
			end)
		end

		timer.Simple(0, function()
			if IsValid(self) then
				self:SetNWFloat("HealthFraction", self:Health() / self:GetMaxHealth())
			end
		end)
	end

	function ENT:Think()
		local selfPos = self:GetPos()
		local dist = math.huge
		for i, ply in ipairs(jcms.GetAliveSweepers()) do  --Get Closest player dist.
			local newDist = ply:GetPos():DistToSqr(selfPos) 
			dist = ((newDist < dist) and newDist) or dist
		end

		if dist > 5000^2 then 
			return --Disable if we're too far.
		end

		local selfTbl = self:GetTable()
		if selfTbl.nextSpawn < CurTime() and not self.dying then
			for i=#selfTbl.spawnedNPCs, 1, -1 do 
				local npc = selfTbl.spawnedNPCs[i]
				if not IsValid(npc) then
					table.remove(selfTbl.spawnedNPCs, i)
				end
			end

			local count = 6 - #selfTbl.spawnedNPCs
			if count > 0 then 
				local fTime = math.floor( CurTime() / 20 ) * 20 -- Sync all spawners
				selfTbl.nextSpawn = fTime + 20

				local filter = RecipientFilter()
				filter:AddAllPlayers()

				self:EmitSound("npc/fast_zombie/fz_alert_far1.wav", 140, 80, 0.75, CHAN_STATIC, 0, 25, filter)
				self:EmitSound("npc/headcrab_poison/ph_rattle" .. tostring(math.random(1,3)) .. ".wav", 140, 80, 1, CHAN_STATIC, 0, 25, filter)
				self:EmitSound("npc/zombie_poison/pz_pain1.wav", 140, 80, 1, CHAN_STATIC, 0, 25, filter) --lvl, pitch, vol

				self:SetSequence("spew")
				self:SetCycle(0)
				local dur = self:SequenceDuration()
				
				local firePos = nil
				local enemy = jcms.GetNearestSweeper( self:GetPos() )

				if IsValid(enemy) then
					firePos = enemy:WorldSpaceCenter()
				end

				timer.Simple(dur * math.Rand(0.6, 0.65), function()
					if IsValid(self) then
						local ball = ents.Create("jcms_charpleball")
						constraint.NoCollide(ball, self, 0, 0)
						ball:SetPos(self:GetBonePosition(self:LookupBone("spine")))
						ball:Spawn()
						ball.Spawner = self

						if firePos then
							local diff = firePos - self:GetPos()
							local len = diff:Length()

							diff.z = math.sqrt(len) + 1000
							diff.x = diff.x / 3 + math.Rand(-32, 32)
							diff.y = diff.y / 3 + math.Rand(-32, 32)
							ball:GetPhysicsObject():SetVelocity(diff)
						else
							local a = math.random() * math.pi * 2
							local cos, sin = math.cos(a), math.sin(a)
							local mag = math.random(300, 500)

							ball:GetPhysicsObject():SetVelocity(Vector(cos*mag, sin*mag, math.Rand(2500, 3500)))
						end

						self:EmitSound("weapons/stinger_fire1.wav", 140, 75)
					end
				end)

				timer.Simple(dur, function()
					if IsValid(self) and self:GetSequenceName( self:GetSequence() ) == "spew" then
						self:SetSequence("idle")
						self:SetCycle(0)
					end
				end)
			end
		end
	end
end

if CLIENT then
	function ENT:Think()
		-- Burst in bloody particles.
		if FrameTime() > 0 and math.random() < 0.23 and self:GetSequenceName( self:GetSequence() ) == "death" then
			local boneIndex = math.random(1, self:GetBoneCount()) -- 0 not included intentionally
			local boneMatrix = self:GetBoneMatrix(boneIndex)
			if boneMatrix then
				local ed = EffectData()
				ed:SetRadius(math.random(48, 96))
				ed:SetOrigin(boneMatrix:GetTranslation())
				ed:SetMagnitude(math.Rand(0.1, 0.3))
				ed:SetFlags(0)
				util.Effect("jcms_bigblast", ed)
			end
		end
	end

	function ENT:OnRemove()
		local ed = EffectData()
		ed:SetRadius(250)
		ed:SetOrigin(self:WorldSpaceCenter())
		ed:SetScale(1)
		ed:SetMagnitude(0.5)
		ed:SetFlags(0)
		util.Effect("jcms_bigblast", ed)

		for i=1, 6 do
			local boneIndex = math.random(1, self:GetBoneCount()) -- 0 not included intentionally
			local boneMatrix = self:GetBoneMatrix(boneIndex)
			if boneMatrix then
				local ed = EffectData()
				ed:SetRadius(math.random(65, 128))
				ed:SetOrigin(boneMatrix:GetTranslation())
				ed:SetMagnitude(math.Rand(0.3, 0.5))
				ed:SetScale(2)
				ed:SetFlags(0)
				util.Effect("jcms_bigblast", ed)
			end
		end

		util.ScreenShake(self:GetPos(), 4, 60, 2, 500, false)
		self:EmitSound("Explo.ww2bomb")
	end
end