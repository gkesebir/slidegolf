extends Node2D
class_name Fireworks

var trail_particles: CPUParticles2D
var burst_particles: CPUParticles2D

func _ready():
	# --- TRAIL PARTICLES ---
	trail_particles = CPUParticles2D.new()
	trail_particles.emitting = true
	trail_particles.amount = 40
	trail_particles.lifetime = 0.3
	trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail_particles.emission_sphere_radius = 4.0
	trail_particles.direction = Vector2(0, 1) # Fire downwards as it goes up
	trail_particles.spread = 15.0
	trail_particles.gravity = Vector2(0, 0)
	trail_particles.initial_velocity_min = 80.0
	trail_particles.initial_velocity_max = 150.0
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1))
	scale_curve.add_point(Vector2(1, 0))
	trail_particles.scale_amount_curve = scale_curve
	trail_particles.scale_amount_min = 8.0
	trail_particles.scale_amount_max = 14.0
	
	var trail_gradient = Gradient.new()
	trail_gradient.set_offset(0, 0.0)
	trail_gradient.set_color(0, Color("fff176")) # Light yellow
	trail_gradient.set_offset(1, 1.0)
	trail_gradient.set_color(1, Color("ff5252", 0)) # Red fade
	trail_gradient.add_point(0.4, Color("ff9800")) # Orange
	trail_particles.color_ramp = trail_gradient
	
	add_child(trail_particles)
	
	# --- BURST PARTICLES ---
	burst_particles = CPUParticles2D.new()
	burst_particles.emitting = false
	burst_particles.one_shot = true
	burst_particles.explosiveness = 0.95
	burst_particles.amount = 120
	burst_particles.lifetime = 2.0
	burst_particles.direction = Vector2(0, -1)
	burst_particles.spread = 180.0
	burst_particles.initial_velocity_min = 350.0
	burst_particles.initial_velocity_max = 600.0
	
	burst_particles.damping_min = 250.0
	burst_particles.damping_max = 350.0
	burst_particles.gravity = Vector2(0, 450.0)
	
	burst_particles.scale_amount_min = 12.0
	burst_particles.scale_amount_max = 24.0
	var b_scale_curve = Curve.new()
	b_scale_curve.add_point(Vector2(0, 1.0))
	b_scale_curve.add_point(Vector2(0.7, 0.8))
	b_scale_curve.add_point(Vector2(1.0, 0.0))
	burst_particles.scale_amount_curve = b_scale_curve
	
	var burst_gradient = Gradient.new()
	burst_gradient.set_offset(0, 0.0)
	burst_gradient.set_color(0, Color(1, 1, 1, 1))
	burst_gradient.set_offset(1, 1.0)
	burst_gradient.set_color(1, Color(1, 1, 1, 0)) # Fade out over the end
	burst_particles.color_ramp = burst_gradient
	
	# Pastel Colors for the burst
	var colors = PackedColorArray([
		Color("f8bbd0"), # Pastel Pink
		Color("b2ebf2"), # Pastel Cyan
		Color("c8e6c9"), # Pastel Green
		Color("fff9c4"), # Pastel Yellow
		Color("e1bee7")  # Pastel Purple
	])
	
	var c_gradient = Gradient.new()
	c_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	c_gradient.set_offset(0, 0.0)
	c_gradient.set_color(0, colors[0])
	c_gradient.set_offset(1, 1.0)
	c_gradient.set_color(1, colors[colors.size() - 1])
	for i in range(1, colors.size() - 1):
		c_gradient.add_point(float(i)/colors.size(), colors[i])
	
	burst_particles.color_initial_ramp = c_gradient
	
	# Rotation
	burst_particles.angular_velocity_min = -360.0
	burst_particles.angular_velocity_max = 360.0
	burst_particles.angle_min = 0.0
	burst_particles.angle_max = 360.0
	
	add_child(burst_particles)

func launch(start_pos: Vector2, target_pos: Vector2):
	position = start_pos
	
	var tween = create_tween()
	# Launch using EaseOutCubic as requested!
	tween.tween_property(self, "position", target_pos, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_apex_reached)

func _on_apex_reached():
	trail_particles.emitting = false
	burst_particles.emitting = true
	
	# Destroy this fireworks node after the burst completes (2.5 seconds lifetime buffer)
	var t = get_tree().create_timer(2.5)
	t.timeout.connect(queue_free)
