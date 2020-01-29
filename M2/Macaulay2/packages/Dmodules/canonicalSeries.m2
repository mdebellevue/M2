--add export command

--isTorusFixed
--distraction
--indicialIdeal
--cssExpts
--cssExptsMult


--Input: J an ideal in a Weyl algebra
--Output: True if ideal is torus fixed, as in SST Lem. 2.3.1. False if not.
isTorusFixed = method();
isTorusFixed(Ideal) := Boolean => (J)->(
    n := numgens ring J//2;
    J' := ideal flatten apply(J_*,f->( 
	    apply(apbFactor(f
		    ),v->(		
		    a := take(v#0,n)|apply(n,i-> 0);
		    b := apply(n,i-> 0)|drop(v#0,n);
		    pTheta := sum apply(v#1,u->( u#0*((ring J)_((u#1)|(u#1)) )));
		    (ring J)_a*pTheta*(ring J)_b
		    ))));
    J == J'
    )

--Input: element in Weyl algebra in a torus-fixed ideal
--Output: list of the form {list a, list b, list of coefficients and exponents for poly p}, as in SST Lem. 2.3.1 
apbFactor = method();
apbFactor(RingElement) := List => (f) -> (
    n := (numgens ring f)//2;
    E := exponents f;
    D := ring f;
    createDpairs D;
    if D_* != (flatten D.dpairVars) then error "The variables in this Weyl algebra are in the wrong order.";
    --Each exponent pair (a,b) for writing terms in f as x^a*p(theta)*\del^b, as in the proof of SST Lem. 2.3.1:
    abList := apply(E,e->(
	    thetaExp := apply(n,i-> min(e#(n+i),e#i)); --We already checked above that the Dpairs match up as coded here.
	    e-(thetaExp|thetaExp)
	    ));
    --List of unique exponent pairs (a,b) that occur in abList:
    UabList := unique abList;
    --The positions of each term in f that corresponds to an element in UabList:
    abPos := apply(UabList,u-> positions(abList,i-> i==u));
    C := flatten entries (coefficients f)#1;
    --Return list of lists of form {a,b,coeff of p(theta), expts of p(theta)}, corresponding to rearrangment of f:
    apply(#abPos,l->(
    	{ UabList#l, apply(abPos#l,j->( {C#j, drop(E#j-UabList#l,n)} )) }
    ))
)

--Input: b is a List of length n (= numVars of ambient space for D)
--       S is a ring for the output
--Output: [theta]_b as in SST p.68
thetaBracketSub = method();
thetaBracketSub(List,Ring) := (RingElement) => (b,S)->( 
    n := length b;
    if n != numgens S then error "length of exponent vector does not match number of variables";
    product apply(n,i-> product apply(b#i,j-> S_i - j))
    )

--Input: element in D in a torus fixed ideal
--Output: List of corresponding gens from homogeneous pieces in the distraction, viewed in ring S
genToDistractionGens = method();
genToDistractionGens(RingElement,Ring) := List => (f,S) -> (
    n := (numgens ring f)//2;
    if n != numgens S then error "mismatched numbers of variables";
    apbF := apbFactor(f);
    sum apply(apbF,q->( 
         b:= drop(q#0,n);
	 --
	 pTheta := sum apply(q#1,v->( sub(v#0,S)*( 
		     product apply(length v#1,k->( product apply(v#1#k,i->( S_k-i))))
		     )));
	 phi := map(S,S,S_*-b);
	 pThetaMinusb := phi(pTheta);
	 thetaBracketSub(b,S)*pThetaMinusb
	 ))
)

--this was called thetaIdeal in the past		    
--Input: torus-fixed left D-ideal J
--Output: the distraction of J, viewed in ring S
distraction = method(); 
distraction(Ideal,Ring) := (Ideal) => (J,S) ->(
    n := numgens ring J//2;
    if n != numgens S then error "mismatched numbers of variables";
    ideal flatten apply(J_*,j-> genToDistractionGens(j,S))
)

--holnomic ideal I
--weight w
--indicialIdeal = method();
--FINISH
--  = distraction(inw(I,flatten{-w|w}))




--Input: 0-dimensional primary ideal I
--Output: corresponding point, as a vector, with its multiplicity  
solveMax = method();
solveMax(Ideal) := List => (I)->(
   l := numgens ring I;
   v := apply(l,i-> 0);
   J := radical I;
   assert(dim J == 0 and degree J == 1);
   flatten entries ( vars ring J % J)
 )

--internal method
--Input: holonomic D-ideal H, weight vector w as List, half the number of variables in H
--Output: list of 0-dimensional ideals encoding css exponents and their multiplicities
beginExptComp = method();
beginExptComp(Ideal,List,ZZ,Ring) := List => (H,w,n,S)->(
    	if not isHolonomic(H) then error "ideal is not holonomic";
	if #w != n then error "weight vector has wrong length";
	J := inw(H,(-w)|w);
    	if not isTorusFixed(J) then error "ideal is not torus-fixed"; 
        primaryDecomposition distraction(J,S)
	)

--Input: holonomic D-ideal H, weight vector w as List
--Output: list of starting monomial exponents for H wrt w
cssExpts = method();
cssExpts(Ideal,List) := List => (H,w)->(
	n:= (numgens ring H)//2;
	t := symbol t;
	S := QQ(monoid [t_1..t_n]);
    	L := beginExptComp(H,w,n,S);
    	apply(L,l-> solveMax(l))
	)

--Input: holonomic D-ideal H, weight vector w as List, 
--Output: list of starting monomial exponents for H wrt w, with multiplicities
cssExptsMult = method(); 
cssExptsMult(Ideal,List) := List => (H,w)->(
	n:= (numgens ring H)//2;
	t := symbol t;
	S := QQ(monoid [t_1..t_n]);
    	L := beginExptComp(H,w,n,S);
    	apply(L,l->( {degree l,solveMax(l)}))
	)    
    


end;
--------------------
--------------------

restart; --
--uninstallPackage "Dmodules"
path = prepend("~/Desktop/Workshop-2019-Minneapolis/M2/Macaulay2/packages/", path);
needsPackage "Dmodules";
viewHelp cssExpts
viewHelp Dmodules
