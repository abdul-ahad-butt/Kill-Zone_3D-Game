extends SceneTree

func _init():
    var stream = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 44100
    
    var duration = 0.1 # seconds
    var num_samples = int(44100 * duration)
    var data = PackedByteArray()
    data.resize(num_samples * 2) # 16 bits = 2 bytes per sample
    
    for i in range(num_samples):
        var t = float(i) / 44100.0
        # Envelope: fast attack, exponential decay
        var envelope = exp(-t * 30.0)
        # Low frequency thump
        var thump = sin(t * 2.0 * PI * 80.0)
        # White noise for the "crunch"
        var noise = randf_range(-1.0, 1.0) * 0.2
        
        var sample = (thump + noise) * envelope * 0.8
        sample = clamp(sample, -1.0, 1.0)
        
        # Convert to 16-bit integer (-32768 to 32767)
        var int_sample = int(sample * 32767)
        
        # Store as little endian bytes
        data[i * 2] = int_sample & 0xFF
        data[i * 2 + 1] = (int_sample >> 8) & 0xFF
        
    stream.data = data
    
    # Save the resource
    DirAccess.make_dir_absolute("res://resources/audio")
    ResourceSaver.save(stream, "res://resources/audio/footstep.tres")
    print("Footstep audio generated!")
    quit()