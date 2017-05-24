module timeevolution_master

export master, master_nh, master_h, master_dynamic, master_nh_dynamic

import ..integrate, ..recast!
using ...bases
using ...states
using ...operators
using ...operators_dense

typealias DecayRates Union{Vector{Float64}, Matrix{Float64}, Void}


function recast!(x::Vector{Complex128}, rho::DenseOperator)
    rho.data = reshape(x, size(rho.data))
end

function recast!(rho::DenseOperator, x::Vector{Complex128})
    nothing
end


function dmaster_h(rho::DenseOperator, H::Operator,
                    Gamma::Void, J::Vector, Jdagger::Vector,
                    drho::DenseOperator, tmp::DenseOperator)
    operators.gemm!(-1im, H, rho, 0, drho)
    operators.gemm!(1im, rho, H, 1, drho)
    for i=1:length(J)
        operators.gemm!(1, J[i], rho, 0, tmp)
        operators.gemm!(1, tmp, Jdagger[i], 1, drho)

        operators.gemm!(-0.5, Jdagger[i], tmp, 1, drho)

        operators.gemm!(1., rho, Jdagger[i], 0, tmp)
        operators.gemm!(-0.5, tmp, J[i], 1, drho)
    end
    return drho
end

function dmaster_h(rho::DenseOperator, H::Operator,
                    Gamma::Vector{Float64}, J::Vector, Jdagger::Vector,
                    drho::DenseOperator, tmp::DenseOperator)
    operators.gemm!(-1im, H, rho, 0, drho)
    operators.gemm!(1im, rho, H, 1, drho)
    for i=1:length(J)
        operators.gemm!(Gamma[i], J[i], rho, 0, tmp)
        operators.gemm!(1, tmp, Jdagger[i], 1, drho)

        operators.gemm!(-0.5, Jdagger[i], tmp, 1, drho)

        operators.gemm!(Gamma[i], rho, Jdagger[i], 0, tmp)
        operators.gemm!(-0.5, tmp, J[i], 1, drho)
    end
    return drho
end

function dmaster_h(rho::DenseOperator, H::Operator,
                    Gamma::Matrix{Float64}, J::Vector, Jdagger::Vector,
                    drho::DenseOperator, tmp::DenseOperator)
    operators.gemm!(-1im, H, rho, 0, drho)
    operators.gemm!(1im, rho, H, 1, drho)
    for j=1:length(J), i=1:length(J)
        operators.gemm!(Gamma[i,j], J[i], rho, 0, tmp)
        operators.gemm!(1, tmp, Jdagger[j], 1, drho)

        operators.gemm!(-0.5, Jdagger[j], tmp, 1, drho)

        operators.gemm!(Gamma[i,j], rho, Jdagger[j], 0, tmp)
        operators.gemm!(-0.5, tmp, J[i], 1, drho)
    end
    return drho
end

function dmaster_h_dynamic(t::Float64, rho::DenseOperator, f::Function,
                    Gamma::DecayRates,
                    drho::DenseOperator, tmp::DenseOperator)
      H, J, Jdagger = f(t, rho)
      _check_input(rho, H, J, Jdagger, Gamma)
      dmaster_h(rho, H, Gamma, J, Jdagger, drho, tmp)
end

function dmaster_nh(rho::DenseOperator, Hnh::Operator, Hnh_dagger::Operator,
                    Gamma::Void, J::Vector, Jdagger::Vector,
                    drho::DenseOperator, tmp::DenseOperator)
    operators.gemm!(-1im, Hnh, rho, 0, drho)
    operators.gemm!(1im, rho, Hnh_dagger, 1, drho)
    for i=1:length(J)
        operators.gemm!(1, J[i], rho, 0, tmp)
        operators.gemm!(1, tmp, Jdagger[i], 1, drho)
    end
    return drho
end

function dmaster_nh(rho::DenseOperator, Hnh::Operator, Hnh_dagger::Operator,
                    Gamma::Vector{Float64}, J::Vector, Jdagger::Vector,
                    drho::DenseOperator, tmp::DenseOperator)
    operators.gemm!(-1im, Hnh, rho, 0, drho)
    operators.gemm!(1im, rho, Hnh_dagger, 1, drho)
    for i=1:length(J)
        operators.gemm!(Gamma[i], J[i], rho, 0, tmp)
        operators.gemm!(1, tmp, Jdagger[i], 1, drho)
    end
    return drho
end

function dmaster_nh(rho::DenseOperator, Hnh::Operator, Hnh_dagger::Operator,
                    Gamma::Matrix{Float64}, J::Vector, Jdagger::Vector,
                    drho::DenseOperator, tmp::DenseOperator)
    operators.gemm!(-1im, Hnh, rho, 0, drho)
    operators.gemm!(1im, rho, Hnh_dagger, 1, drho)
    for j=1:length(J), i=1:length(J)
        operators.gemm!(Gamma[i,j], J[i], rho, 0, tmp)
        operators.gemm!(1, tmp, Jdagger[j], 1, drho)
    end
    return drho
end

function dmaster_nh_dynamic(t::Float64, rho::DenseOperator, f::Function,
                    Gamma::DecayRates,
                    drho::DenseOperator, tmp::DenseOperator)
      Hnh, Hnh_dagger, J, Jdagger = f(t, rho)
      _check_input(rho, Hnh, J, Jdagger, Gamma)
      dmaster_nh(rho, Hnh, Hnh_dagger, Gamma, J, Jdagger, drho, tmp)
end


function _check_input(rho0::DenseOperator, H::Operator, J::Vector, Jdagger::Vector, Gamma::DecayRates)
    check_samebases(rho0, H)
    for j=J
        @assert typeof(j) <: Operator
        check_samebases(rho0, j)
    end
    for j=Jdagger
        @assert typeof(j) <: Operator
        check_samebases(rho0, j)
    end
    @assert length(J)==length(Jdagger)
    if typeof(Gamma) == Matrix{Float64}
        @assert size(Gamma, 1) == size(Gamma, 2) == length(J)
    elseif typeof(Gamma) == Vector{Float64}
        @assert length(Gamma) == length(J)
    end
end

"""
    timeevolution.master_h(tspan, rho0, H, J; <keyword arguments>)

Integrate the master equation with dmaster_h as derivative function.

Further information can be found at [`master`](@ref).
"""
function master_h(tspan, rho0::DenseOperator, H::Operator, J::Vector;
                Gamma::DecayRates=nothing,
                Jdagger::Vector=dagger.(J),
                fout::Union{Function,Void}=nothing,
                tmp::DenseOperator=copy(rho0),
                kwargs...)
    tspan_ = convert(Vector{Float64}, tspan)
    _check_input(rho0, H, J, Jdagger, Gamma)
    dmaster_(t, rho::DenseOperator, drho::DenseOperator) = dmaster_h(rho, H, Gamma, J, Jdagger, drho, tmp)
    x0 = reshape(rho0.data, length(rho0))
    state = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    dstate = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    return integrate(tspan, dmaster_, x0, state, dstate, fout; kwargs...)
end

master_h(tspan, psi0::Ket, H::Operator, J::Vector; kwargs...) = master_h(tspan, dm(psi0), H, J; kwargs...)


"""
    timeevolution.master_nh(tspan, rho0, H, J; <keyword arguments>)

Integrate the master equation with dmaster_nh as derivative function.

In this case the given Hamiltonian is assumed to be the non-hermitian version:

```math
H_{nh} = H - \\frac{i}{2} \\sum_k J^†_k J_k
```

Further information can be found at [`master`](@ref).
"""
function master_nh(tspan, rho0::DenseOperator, Hnh::Operator, J::Vector;
                Gamma::DecayRates=nothing,
                Hnhdagger::Operator=dagger(Hnh),
                Jdagger::Vector=dagger.(J),
                fout::Union{Function,Void}=nothing,
                tmp::DenseOperator=copy(rho0),
                kwargs...)
    tspan_ = convert(Vector{Float64}, tspan)
    _check_input(rho0, Hnh, J, Jdagger, Gamma)
    dmaster_(t, rho::DenseOperator, drho::DenseOperator) = dmaster_nh(rho, Hnh, Hnhdagger, Gamma, J, Jdagger, drho, tmp)
    x0 = reshape(rho0.data, length(rho0))
    state = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    dstate = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    return integrate(tspan, dmaster_, x0, state, dstate, fout; kwargs...)
end

master_nh(tspan, psi0::Ket, Hnh::Operator, J::Vector; kwargs...) = master_nh(tspan, dm(psi0), Hnh, J; kwargs...)


"""
    timeevolution.master(tspan, rho0, H, J; <keyword arguments>)

Time-evolution according to a master equation.

There are two implementations for integrating the master equation:

* [`master_h`](@ref): Usual formulation of the master equation.
* [`master_nh`](@ref): Variant with non-hermitian Hamiltonian.

For dense arguments the `master` function calculates the
non-hermitian Hamiltonian and then calls master_nh which is slightly faster.

# Arguments
* `tspan`: Vector specifying the points of time for which output should
        be displayed.
* `rho0`: Initial density operator. Can also be a state vector which is
        automatically converted into a density operator.
* `H`: Arbitrary operator specifying the Hamiltonian.
* `J`: Vector containing all jump operators which can be of any arbitrary
        operator type.
* `Gamma=nothing`: Vector or matrix specifying the coefficients (decay rates)
        for the jump operators. If nothing is specified all rates are assumed
        to be 1.
* `Jdagger=dagger.(J)`: Vector containing the hermitian conjugates of the jump
        operators. If they are not given they are calculated automatically.
* `fout=nothing`: If given, this function `fout(t, rho)` is called every time
        an output should be displayed. ATTENTION: The given state rho is not
        permanent! It is still in use by the ode solver and therefore must not
        be changed.
* `kwargs...`: Further arguments are passed on to the ode solver.
"""
function master(tspan, rho0::DenseOperator, H::Operator, J::Vector;
                Gamma::DecayRates=nothing,
                Jdagger::Vector=dagger.(J),
                fout::Union{Function,Void}=nothing,
                tmp::DenseOperator=copy(rho0),
                kwargs...)
    tspan_ = convert(Vector{Float64}, tspan)
    _check_input(rho0, H, J, Jdagger, Gamma)
    dmaster_(t, rho::DenseOperator, drho::DenseOperator) = dmaster_h(rho, H, Gamma, J, Jdagger, drho, tmp)
    x0 = reshape(rho0.data, length(rho0))
    state = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    dstate = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    return integrate(tspan, dmaster_, x0, state, dstate, fout; kwargs...)
end

function master(tspan, rho0::DenseOperator, H::DenseOperator, J::Vector{DenseOperator};
                Gamma::DecayRates=nothing,
                Jdagger::Vector{DenseOperator}=dagger.(J),
                fout::Union{Function,Void}=nothing,
                tmp::DenseOperator=copy(rho0),
                kwargs...)
    tspan_ = convert(Vector{Float64}, tspan)
    _check_input(rho0, H, J, Jdagger, Gamma)
    Hnh = copy(H)
    if typeof(Gamma) == Matrix{Float64}
        for i=1:length(J), j=1:length(J)
            Hnh -= 0.5im*Gamma[i,j]*Jdagger[i]*J[j]
        end
    elseif typeof(Gamma) == Vector{Float64}
        for i=1:length(J)
            Hnh -= 0.5im*Gamma[i]*Jdagger[i]*J[i]
        end
    else
        for i=1:length(J)
            Hnh -= 0.5im*Jdagger[i]*J[i]
        end
    end
    Hnhdagger = dagger(Hnh)
    dmaster_(t, rho::DenseOperator, drho::DenseOperator) = dmaster_nh(rho, Hnh, Hnhdagger, Gamma, J, Jdagger, drho, tmp)
    x0 = reshape(rho0.data, length(rho0))
    state = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    dstate = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    return integrate(tspan_, dmaster_, x0, state, dstate, fout; kwargs...)
end

master(tspan, psi0::Ket, H::Operator, J::Vector; kwargs...) = master(tspan, dm(psi0), H, J; kwargs...)


"""
    timeevolution.master_dynamic(tspan, rho0, f; <keyword arguments>)

Time-evolution according to a master equation with a dynamic non-hermitian Hamiltonian and J.

In this case the given Hamiltonian is assumed to be the non-hermitian version.

```math
H_{nh} = H - \\frac{i}{2} \\sum_k J^†_k J_k
```

For further information look at [`master_dynamic`](@ref).
"""
function master_nh_dynamic(tspan, rho0::DenseOperator, f::Function;
                Gamma::DecayRates=nothing,
                fout::Union{Function,Void}=nothing,
                tmp::DenseOperator=copy(rho0),
                kwargs...)
    tspan_ = convert(Vector{Float64}, tspan)
    dmaster_(t, rho::DenseOperator, drho::DenseOperator) = dmaster_nh_dynamic(t, rho, f, Gamma, drho, tmp)
    x0 = reshape(rho0.data, length(rho0))
    state = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    dstate = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    return integrate(tspan, dmaster_, x0, state, dstate, fout; kwargs...)
end

master_nh_dynamic(tspan, psi0::Ket, f::Function; kwargs...) = master_nh_dynamic(tspan, dm(psi0), f; kwargs...)


"""
    timeevolution.master_dynamic(tspan, rho0, f; <keyword arguments>)

Time-evolution according to a master equation with a dynamic Hamiltonian and J.

There are two implementations for integrating the master equation with dynamic
operators:

* [`master_dynamic`](@ref): Usual formulation of the master equation.
* [`master_nh_dynamic`](@ref): Variant with non-hermitian Hamiltonian.

# Arguments
* `tspan`: Vector specifying the points of time for which output should be displayed.
* `rho0`: Initial density operator. Can also be a state vector which is
        automatically converted into a density operator.
* `f`: Function `f(t, rho) -> (H, J, Jdagger)` returning the time and/or state dependent
        Hamiltonian and Jump operators.
* `Gamma=nothing`: Vector or matrix specifying the coefficients (decay rates)
        for the jump operators. If nothing is specified all rates are assumed
        to be 1.
* `fout=nothing`: If given, this function `fout(t, rho)` is called every time
        an output should be displayed. ATTENTION: The given state rho is not
        permanent! It is still in use by the ode solver and therefore must not
        be changed.
* `kwargs...`: Further arguments are passed on to the ode solver.
"""
function master_dynamic(tspan, rho0::DenseOperator, f::Function;
                Gamma::DecayRates=nothing,
                fout::Union{Function,Void}=nothing,
                tmp::DenseOperator=copy(rho0),
                kwargs...)
    tspan_ = convert(Vector{Float64}, tspan)
    dmaster_(t, rho::DenseOperator, drho::DenseOperator) = dmaster_h_dynamic(t, rho, f, Gamma, drho, tmp)
    x0 = reshape(rho0.data, length(rho0))
    state = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    dstate = DenseOperator(rho0.basis_l, rho0.basis_r, rho0.data)
    return integrate(tspan, dmaster_, x0, state, dstate, fout; kwargs...)
end

master_dynamic(tspan, psi0::Ket, f::Function; kwargs...) = master_dynamic(tspan, dm(psi0), f; kwargs...)

end #module
