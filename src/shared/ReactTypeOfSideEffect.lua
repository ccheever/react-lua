return {

    -- Don't change these two values. They're used by React Dev Tools
    NoEffect = 0, -- 0b000000000000
    PerformedWork = 1, -- 0b000000000001

    -- You can change the rest (and add more)
    Placement = 2, -- 0b000000000010
    Update = 4, -- 0b000000000100
    PlacementAndUpdate = 6, -- 0b000000000110
    Deletion = 8, -- 0b000000001000
    ContentReset = 16, -- 0b000000010000
    Callback = 32, -- 0b000000100000
    DidCapture = 64, -- 0b000001000000
    Ref = 128, -- 0b000010000000
    ErrLog = 256, -- 0b000100000000
    Snapshot = 2048, -- 0b100000000000

    -- Union of all host effects
    HostEffectMask = 2559, -- 0b100111111111

    Incomplete = 512, -- 0b001000000000
    ShouldCapture = 1024, -- 0b010000000000 


}