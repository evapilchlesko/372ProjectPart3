using GLMakie
using LinearAlgebra

# --- 1. Shape Definitions ---
abstract type Shape end

struct Ball <: Shape
    name::String
    color::Symbol
end

struct Square <: Shape
    name::String
    color::Symbol
end

struct Triangle <: Shape
    name::String
    color::Symbol
end

# --- 2. Multiple Dispatch Collision Logging ---
collide(a::Ball, b::Ball)     = "[Circle] LOG: $(a.name) and $(b.name) had an elastic collision."
collide(a::Square, b::Square) = "[Square] LOG: $(a.name) and $(b.name) clanked together!"
collide(a::Ball, b::Square)   = "[Mixed] LOG: $(a.name) bounced off the flat side of $(b.name)."
collide(a::Triangle, b::Shape) = "[Alert] LOG: $(a.name) poked $(b.name) with a vertex!"
collide(a::Shape, b::Shape)   = "[Misc] LOG: Generic collision: $(a.name) + $(b.name)."

# --- 3. Simulation Setup ---
const N = 6  
const RADIUS = 40.0
const DT = 0.1
const CANVAS_SIZE = 600.0

types = [Ball("Ball_$i", :skyblue) for i in 1:2] ∪ 
        [Square("Box_$i", :tomato) for i in 1:2] ∪ 
        [Triangle("Tri_$i", :limegreen) for i in 1:2]

positions = Observable([Point2f(rand(100:500), rand(100:500)) for _ in 1:N])
velocities = [20.0 .* randn(Point2f) for _ in 1:N]
log_text = Observable("--- Collision Terminal ---\nReady for impact...")

# --- 4. The Interactive GUI ---
fig = Figure(size = (1000, 700))

# THE FIX: Lock the view directly in the Axis creation
ax = Axis(fig[1, 1], 
    limits = (0, CANVAS_SIZE, 0, CANVAS_SIZE), 
    title = "Julia Multiple Dispatch Physics",
    aspect = DataAspect(),
    xpanlock = true, 
    ypanlock = true, 
    xzoomlock = true, 
    yzoomlock = true,
    xrectzoom = false,
    yrectzoom = false
)

terminal_box = Label(fig[1, 2], log_text, tellheight=false, width=350, 
                     halign=:left, justification=:left, word_wrap=true)

for i in 1:N
    m = types[i] isa Ball ? :circle : (types[i] isa Square ? :rect : :utriangle)
    scatter!(ax, lift(p -> p[i], positions), marker=m, markersize=RADIUS*2, color=types[i].color)
end

# --- 5. Interaction: Dragging ---
selected_idx = Ref{Int}(0)

on(events(ax.scene).mousebutton) do event
    if event.action == Mouse.press
        # THE FIX: use mouseposition helper and force it to Point2f
        m_pos = Point2f(mouseposition(ax.scene)) 
        for i in 1:N
            if norm(positions[][i] - m_pos) < RADIUS
                selected_idx[] = i
            end
        end
    elseif event.action == Mouse.release
        selected_idx[] = 0
    end
end

# --- 6. Physics Loop ---
function update_physics!()
    pos = positions[]
    new_pos = copy(pos)
    
    for i in 1:N
        if i == selected_idx[]
            # Follow mouse if dragged
            new_pos[i] = Point2f(mouseposition(ax.scene))
            continue
        end

        new_pos[i] += velocities[i] * DT

        # Wall Bounces
        if new_pos[i][1] < RADIUS || new_pos[i][1] > CANVAS_SIZE - RADIUS
            velocities[i] = Point2f(-velocities[i][1], velocities[i][2])
            new_pos[i] = Point2f(clamp(new_pos[i][1], RADIUS, CANVAS_SIZE-RADIUS), new_pos[i][2])
        end
        if new_pos[i][2] < RADIUS || new_pos[i][2] > CANVAS_SIZE - RADIUS
            velocities[i] = Point2f(velocities[i][1], -velocities[i][2])
            new_pos[i] = Point2f(new_pos[i][1], clamp(new_pos[i][2], RADIUS, CANVAS_SIZE-RADIUS))
        end

        # Object Collisions
        for j in (i+1):N
            if norm(new_pos[i] - new_pos[j]) < RADIUS * 1.2
                msg = collide(types[i], types[j])
                current_logs = split(log_text[], "\n")
                log_text[] = msg * "\n" * join(current_logs[1:min(end, 10)], "\n")
                
                v_tmp = velocities[i]
                velocities[i] = velocities[j]
                velocities[j] = v_tmp
            end
        end
    end
    positions[] = new_pos
end

# --- 7. Execution ---
display(fig)

@async while isopen(fig.scene)
    update_physics!()
    sleep(0.01)
end