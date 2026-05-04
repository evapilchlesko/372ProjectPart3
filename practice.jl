#=
  Name: Eva Lesko, Joure Fadhil 
  Course: CS 372
  Instructor: McCann
  Due Date: 4 May 2026

  Description: 
  This program creates an interactive 2D physics simulation using GLMakie. 
  It visualizes multiple moving shapes (Balls, Squares, and Triangles) 
  within a bounded canvas. The program demonstrates Julia’s multiple 
  dispatch by generating different collision log messages depending on 
  the types of objects that collide. Users can also interact with the 
  simulation by clicking and dragging objects in real time.

  Operational Requirements:
  - Language: Julia (v1.x)
  - Packages: GLMakie, LinearAlgebra, Colors
  - Input: No external input required (random initialization)
  - Output: Interactive GUI window displaying simulation and collision logs
=#
using GLMakie
using LinearAlgebra
using Colors

# ============================================================
# 1. Shape Definitions
# ------------------------------------------------------------
# Define an abstract type `Shape` and concrete subtypes.
# Using 'mutable struct' allows us to change the color field
# dynamically during the simulation.
# ============================================================

abstract type Shape end

mutable struct Ball <: Shape
    name::String
    color::Any
end

mutable struct Square <: Shape
    name::String
    color::Any
end

mutable struct Triangle <: Shape
    name::String
    color::Any
end

# ============================================================
# 2. Multiple Dispatch Collision Logging
# ------------------------------------------------------------
# Different collide methods are selected automatically
# based on the types of the two objects that collide.
# This demonstrates Julia’s multiple dispatch.
# ============================================================

# Ball-Ball collision
collide(a::Ball, b::Ball) =
    "LOG: $(a.name) and $(b.name) bounced off eachother."

# Square-Square collision
collide(a::Square, b::Square) =
    "LOG: $(a.name) and $(b.name) clanked together!"

# Ball-Square collision (SPECIAL BEHAVIOR: Swaps Colors)
function collide(a::Ball, b::Square)
    # Swap the colors
    temp_color = a.color
    a.color = b.color
    b.color = temp_color
    
    return "LOG: $(a.name) and $(b.name) collided and swapped colors!"
end

# Support the reverse order for Ball-Square dispatch
collide(a::Square, b::Ball) = collide(b, a)

# Triangle interacting with any shape
collide(a::Triangle, b::Shape) =
    "LOG: $(a.name) poked $(b.name) with a vertex!"

# Generic fallback for any other combination
collide(a::Shape, b::Shape) =
    "LOG: Generic collision: $(a.name) + $(b.name)."

# ============================================================
# 3. Simulation Setup
# ------------------------------------------------------------
# Define constants and initialize simulation data:
#   - types       : list of objects
#   - positions   : Observable (reactive positions for plotting)
#   - velocities  : movement vectors 
#   - log_text    : collision log displayed in GUI
# ============================================================

const N = 6                 # total number of objects
const RADIUS = 40.0        # size of objects and collision radius
const DT = 0.1             # time step for simulation updates
const CANVAS_SIZE = 600.0  # width/height of simulation area

# Create objects: 2 Balls, 2 Squares, 2 Triangles
types = [Ball("Ball-$i", :pink) for i in 1:2] ∪ 
        [Square("Square-$i", :red) for i in 1:2] ∪ 
        [Triangle("Triangle-$i", :orange) for i in 1:2]

# Random initial positions (wrapped in Observable for reactive updates)
positions = Observable([Point2f(rand(100:500), rand(100:500)) for _ in 1:N])

# Random velocities for each object (reset to higher speed for snappier feel)
velocities = [20.0 .* randn(Point2f) for _ in 1:N] # fused broadcasting

# Text shown in the terminal panel
log_text = Observable("--- Collision Terminal ---\nReady for impact...")

# ============================================================
# 4. The Interactive GUI
# ------------------------------------------------------------
# Create the main figure, simulation axis, and log panel.
# ============================================================

fig = Figure(size = (1000, 700))

# Axis setup (locked to prevent zooming/panning)
ax = Axis(fig[1, 1], 
    limits = (0, CANVAS_SIZE, 0, CANVAS_SIZE), 
    title = "Final Project",
    aspect = DataAspect(),
    xpanlock = true, 
    ypanlock = true, 
    xzoomlock = true, 
    yzoomlock = true,
    xrectzoom = false,
    yrectzoom = false,
    xgridvisible = false, 
    ygridvisible = false
)
hidedecorations!(ax) # Removes numbers/ticks while keeping the border

# Text box for displaying collision logs
terminal_box = Label(fig[1, 2], log_text,
    tellheight=false,
    width=350, 
    halign=:left,
    valign=:top,
    justification=:left,
    word_wrap=true,
    font = "monospace" 
)

# Plot each object using a marker based on its type
for i in 1:N
    # Choose marker shape depending on object type
    m = types[i] isa Ball ? :circle :
        (types[i] isa Square ? :rect : :utriangle)

    # Draw object with reactive position
    scatter!(
        ax,
        lift(p -> p[i], positions),   
        marker = m,
        markersize = RADIUS * 2,
        # Lift color so the plot updates when colors are swapped
        color = lift(p -> types[i].color, positions) 
    )
end

# ============================================================
# 5. Interaction: Dragging
# ------------------------------------------------------------
# Allows user to click and drag objects with the mouse.
# selected_idx stores the index of the currently dragged object.
# ============================================================

selected_idx = Ref{Int}(0)

on(events(ax.scene).mousebutton) do event
    if event.action == Mouse.press
        # Get current mouse position in scene coordinates
        m_pos = Point2f(mouseposition(ax.scene)) 

        # Check if mouse is within radius of any object
        for i in 1:N
            if norm(positions[][i] - m_pos) < RADIUS
                selected_idx[] = i   # select object
            end
        end

    elseif event.action == Mouse.release
        # Release object when mouse button is lifted
        selected_idx[] = 0
    end
end

# ============================================================
# 6. Physics Loop
# ------------------------------------------------------------
# Updates positions, handles:
#   - dragging behavior
#   - wall collisions
#   - object-object collisions
# ============================================================

function update_physics!()
    pos = positions[]          # current positions
    new_pos = copy(pos)        # create updated positions

    for i in 1:N

        # If object is being dragged, follow mouse
        if i == selected_idx[]
            new_pos[i] = Point2f(mouseposition(ax.scene))
            continue
        end

        # Update position using velocity
        new_pos[i] += velocities[i] * DT

        # ------------------------
        # Wall Bounces
        # ------------------------

        # Check horizontal boundaries
        if new_pos[i][1] < RADIUS || new_pos[i][1] > CANVAS_SIZE - RADIUS
            velocities[i] = Point2f(-velocities[i][1], velocities[i][2])
            new_pos[i] = Point2f(
                clamp(new_pos[i][1], RADIUS, CANVAS_SIZE - RADIUS),
                new_pos[i][2]
            )
        end

        # Check vertical boundaries
        if new_pos[i][2] < RADIUS || new_pos[i][2] > CANVAS_SIZE - RADIUS
            velocities[i] = Point2f(velocities[i][1], -velocities[i][2])
            new_pos[i] = Point2f(
                new_pos[i][1],
                clamp(new_pos[i][2], RADIUS, CANVAS_SIZE - RADIUS)
            )
        end

        # ------------------------
        # Object Collisions
        # ------------------------
        for j in (i+1):N
            # Check if objects are close enough to collide
            dist = norm(new_pos[i] - new_pos[j])
            if dist < RADIUS * 1.2

                # Generate log message (and swap colors via multiple dispatch)
                msg = collide(types[i], types[j]) # multiple dispatch

                # Keep recent log messages (limit to ~10 lines)
                current_logs = split(log_text[], "\n")
                header = current_logs[1]
                history = current_logs[2:end]
                
                if length(history) > 10
                    history = history[2:end]
                end

                log_text[] = header * "\n" * join(history, "\n") * "\n" * msg

                # Simple collision response: swap velocities
                v_tmp = velocities[i]
                velocities[i] = velocities[j]
                velocities[j] = v_tmp

                # OVERLAP FIX: Push them apart so they don't trigger the log again
                midpoint_vec = normalize(new_pos[i] - new_pos[j])
                push_amount = (RADIUS * 1.21) - dist
                
                new_pos[i] += midpoint_vec * (push_amount / 2)
                new_pos[j] -= midpoint_vec * (push_amount / 2)
            end
        end
    end

    # Update observable → triggers redraw in GLMakie
    positions[] = new_pos
end

# ============================================================
# 7. Execution
# ------------------------------------------------------------
# Display the figure and continuously update the simulation
# while the window remains open.
# ============================================================

display(fig)

@async while isopen(fig.scene) # macros 
    update_physics!()
    sleep(0.01)   # Reset to 0.01 for smooth high-speed performance
end