using GLMakie

function start_visual_app()
    # 1. 'size' is correct
    fig = Figure(size = (1000, 800))
    
    ax = Axis(fig[1, 1], title = "Interactive Sine Wave", 
              xlabel = "Time", ylabel = "Amplitude")
    
    
    frequency = Observable(1.0)
    x = range(0, 10, length=1000)
    y = lift(frequency) do f
        return sin.(f .* x)
    end

    sl = Slider(fig[2, 1], range = 0.1:0.1:10.0, startvalue = 1.0)
        connect!(frequency, sl.value)

    # Layout: Put buttons in a column to the right of the plot and slider
    commandlabels = ["Option A", "Option B", "Option C"] 
    CommandButtonGrid = fig[1:2, 2] = GridLayout(width=200)

    # 2. FIXED: Changed 'textsize' to 'fontsize'
    commandbuttons = [Button(fig, label=l, tellheight=false, width=150, 
                      buttoncolor=:red, fontsize=20) for l in commandlabels]
    
    # Place buttons in the grid
    CommandButtonGrid[1:3, 1] = commandbuttons

    lines!(ax, x, y, color = :blue, linewidth = 3)

    

    return fig
end

# 1. Create the figure object
my_fig = start_visual_app()

# 2. Display the figure and capture the 'screen'
screen = display(my_fig)

# 3. Wait on the screen object
wait(screen)