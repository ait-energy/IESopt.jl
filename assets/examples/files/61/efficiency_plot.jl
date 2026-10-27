using Plots
import JuMP
Pmax = 100.
a,b,c = [0.7012, 0.0662, 0.3671 ] # coeffs for efficiency

function eta(P::Float64)
    prel = P/Pmax
    return 0.1 + c *( prel^a / (prel^a + b^a)  )
end

function eta_const(P::Float64)
    return 0.35
end
P = collect( range(0, Pmax, 110) )
eta_P = eta.(P)

p1 = plot(P, eta_P, label="True efficiency")

input_bp = collect( range(0, Pmax, 20) ) #20 breakpoints
ouptput_bp = eta.(input_bp)
    

plot!(p1, input_bp, ouptput_bp, label="piecewise linear, 20 BPs")
plot!(p1, input_bp, eta_const.(input_bp), label="constant efficiency")

input_bp = collect( range(0, Pmax, 10) ) #20 breakpoints
ouptput_bp = eta.(input_bp)

plot!(p1, input_bp, ouptput_bp, label="piecewise linear, 10 BPs")

input_bp = [0, 5, 10, 15.0, 20, 25, 45, 60, 80, 100]
ouptput_bp = eta.(input_bp)

plot!(p1, input_bp, ouptput_bp, label="piecewise linear, 10 BPs - not equally spaced")