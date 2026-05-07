function flux = computeFluxes(nodes, params, time)
% Computes fc, fw, fwt in ppm m s-2

dt = seconds(time(2) - time(1));

% ---- unpack ----
Cr = nodes.Cr;
Cs = nodes.Cs;
Cw = nodes.Cw;
% Ca = nodes.Ca;

ka = params.ka;
% kc = params.kc;
kw = params.kw;
S = params.S;
Vm = params.Vm;

% ---- concentrations ----
dCsdt = gradient(Cs, dt);
dCrdt = gradient(Cr, dt);

% Flux through bottom membrane, fc (Eq. 10)
flux.fc = Vm/S * (dCsdt - dCrdt) + ka * (Cs - Cr);

% Flux beneath chamber, fw (Eq. 19)
flux.fw = kw .* (Cw - flux.Cc);

% True flux, fwt (Eq. 24)
flux.fwt = kw .* (Cw - Cr);
end
