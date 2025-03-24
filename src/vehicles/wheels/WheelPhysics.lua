RW_WheelPhysics = {}

function RW_WheelPhysics:updateFriction(_, _, groundWetness)

    local densityType = self.densityType ~= FieldGroundType.NONE
    local snowFactor

    if self.hasSnowContact then
        groundWetness = 0
        if self.snowHeight ~= nil then
            snowFactor = 1 + (self.snowHeight * 0.33)
        else
            snowFactor = 1
        end
    else
        snowFactor = 0
    end

    local ground = WheelsUtil.getGroundType(densityType, self.contact ~= WheelContactType.GROUND, self.groundDepth)
    local friction = WheelsUtil.getTireFriction(self.tireType, ground, groundWetness, snowFactor)

    local width = self.width
    local mass = self.vehicle:getTotalMass()
    local widthToMassRatio = math.min(width / (mass / #self.vehicle.spec_wheels.wheels), 1)

    friction = friction / (1.5 - math.min(width, 1))

    if self.hasSnowContact and mass < 8 then
        if widthToMassRatio > 0.06 and widthToMassRatio < 0.12 then
            friction = friction * (1 + (width / 5))
        else
            friction = friction * (1 - (width / 5))
        end
    end

    if self.hasSnowContact then

        local timeSinceLastRain = g_currentMission.environment.weather.timeSinceLastRain or 0
        friction = friction / math.clamp(timeSinceLastRain / 1440, 1, 3)

    end

    if self.vehicle:getLastSpeed() > 0.2 and friction ~= self.tireGroundFrictionCoeff then
        self.tireGroundFrictionCoeff = friction
        self.isFrictionDirty = true
    end

end

WheelPhysics.updateFriction = Utils.overwrittenFunction(WheelPhysics.updateFriction, RW_WheelPhysics.updateFriction)