newPackage(
        "PolynomialAlgebra",
        Version => "0.1", 
        Date => "16 Feb 2016",
        Authors => {{Name => "Frank Moore", 
                  Email => "", 
                  HomePage => ""},
              {Name => "Mike Stillman", 
                  Email => "", 
                  HomePage => ""}
              },
        Headline => "Non-commutative polynomial algebra",
        DebuggingMode => true
        )

export {
    "NCGB", -- uugh: change name!
    "NCReduction2Sided",
    "FreeAlgebra", -- change this name too!
    "sequenceToVariableSymbols"
    }

debug Core

FreeAlgebra = new Type of EngineRing
FreeAlgebra.synonym = "noncommutative polynomial ring"

new FreeAlgebra from List := (EngineRing, inits) -> new EngineRing of RingElement from new HashTable from inits

getNameIfAny = (k) -> expression if hasAttribute(k,ReverseDictionary) then getAttribute(k,ReverseDictionary) else k

-- MES.  do we really need all 5 of these?
expression FreeAlgebra := R -> (
     if hasAttribute(R,ReverseDictionary) then return expression getAttribute(R,ReverseDictionary);
     k := last R.baseRings;
     (getNameIfAny k) (R.generatorSymbols)
     )
net FreeAlgebra := R -> (
     if hasAttribute(R,ReverseDictionary) then toString getAttribute(R,ReverseDictionary)
     else net expression R)
describe FreeAlgebra := R -> (
     k := last R.baseRings;
     net ((getNameIfAny k) R.generatorSymbols)
     )
toExternalString FreeAlgebra := R -> (
    --toString describe R
     k := last R.baseRings;
     toString ((getNameIfAny k) R.generatorSymbols)
     )
toString FreeAlgebra := R -> (
    toString expression R
    -- 
    -- if hasAttribute(R,ReverseDictionary) then toString getAttribute(R,ReverseDictionary)
    -- else toString expression R
    )

-- Currently, we are using findSymbols in m2/ofcm.m2 instead of this.
sequenceToVariableSymbols = args -> (
    variables := splice args;
    v := flatten toList apply(variables, x -> if class x === MutableList then toList x else x);
    for v0 in v list (
	    try baseName v0
	    else if instance(v0,String) and match("[[:alnum:]$]+",v0) then getSymbol v0
	    else error ("name " | v0 | " not usable as a variable")
       )
    )

-- MES: remove this older code:
-* getVariableSymbols = method()
getVariableSymbols List := variables -> (
    genSymbols := sequenceToVariableSymbols variables;

    << "symbols: " << genSymbols << endl;
    --newNCAlgebra(A, v)
    genSymbols
    )
*-

-- TODO (11 Jan 2017 MS+FM), now (19 Dec 2017 MS+FM), and again Dec 2018...!
--   1. handle multigradings
--   2. handle different monomial orders
--     e.g. elimination order.
--   3. check on: ring map evaluations, promote, lift?
--   4. look at other top level rings (and do what with them?)
--   5. net, expression, toString...  DONE
--   6. check on listForm (what is the issue?)
--       problem #1: 'listForm RingElement' is making monomials into exponent vectors.
--       problem #2: we need a way of getting an element of R from a noncommutative monomial
--       issue #3: want a form where the monomials come out as lists of variables.
--   7. use, make it so we can create this ring without assigning the variables to global symbols
--   8. make sure multiplication is using a heap based approach.
--   9. need a good subword lookup table, for reduction wrt a GB.
-- TODO for PolynomialAlgebra.hpp,cpp:
--   - make monoid routines for the cryptic uses.
--   - figure out backInserter, i.e. conform to the standard c++ lib
--   - add in degree support
--   - add in e.g. leadMonomial, support.  
Ring List := (A, args) -> (
   -- get the symbols associated to the list that is passed in, in case the variables have been used earlier.
   opts := new OptionTable from {Degrees=>null, DegreeRank=>null};
   (opts,args) = override(opts,toSequence args);
   varList := args;
   if not (A.?Engine and A.Engine) then
       error "expected coefficient ring handled by the engine";
   --varSymbols := sequenceToVariableSymbols toSequence varList;
   varSymbols := findSymbols toSequence varList;
   if #varSymbols == 0 then error "Expected at least one variable.";
   (degs,degrk) := processDegrees( opts.Degrees, opts.DegreeRank, length varSymbols);
   rawR := rawNCFreeAlgebra(raw A, toSequence(varSymbols/toString), raw degreesRing degrk, flatten degs);
   R := new FreeAlgebra from {
       (symbol RawRing) => rawR,
       (symbol generators) => {},
       (symbol generatorSymbols) => varSymbols,
       --(symbol generatorExpressions) => hashTable apply(#varList, i -> (i,expression varList#i)),
       (symbol generatorExpressions) => for v in varSymbols list if instance(v,Symbol) then v else expression v,
       (symbol degreesRing) => degreesRing degrk,
       (symbol degreeLength) => degrk,
       (symbol degrees) => degs,
       (symbol isCommutative) => false,
       (symbol CoefficientRing) => A,
       (symbol cache) => new CacheTable from {},
       (symbol baseRings) => append(A.baseRings,A)
       };
   newGens := for i from 0 to #varSymbols-1 list varSymbols#i <- new R from R.RawRing_i;
   R.generators = newGens;
   commonEngineRingInitializations R;
   --- need to fix net of an RingElement coming from a NCPolynomial ring.
   processFactor := (k,v) -> if v =!= 1 then Power{R.generatorExpressions#k, v} else R.generatorExpressions#k;
   processFactors := facs -> (
	  if #facs  === 1
	  then processFactor facs#0
	  else new Product from apply(facs, processFactor));
   -- TODO:
   -- In order to get expression R to display monomials correctly, one must:
   -- 1. Create a new function which returns (coeff, a list of integers representing the monomial)
   -- 2. Use this function below, together with a modified version of the code above to
   --    create an expression of a monomial.
   expression R := f -> (
	       (
		    rawP := rawPairs(raw coefficientRing R, raw f);
		    -- apply the following function to the output of rawPairs
		    (coeffs,monoms) -> (
			 if #coeffs === 0
			 then expression 0
			 else sum(coeffs,monoms, (a,m) -> expression (if a == 1 then 1 else promote(a,A)) * expression (if m == {} then 1 else processFactors m))
			 )
		    ) (rawP#0, rawP#1 / rawSparseListFormMonomial)
        );
   net R := f -> net expression f;
   R
   );

FreeAlgebra _ ZZ := (R, n) -> (R.generators)#n
coefficientRing FreeAlgebra := R -> last R.baseRings

degreesRing FreeAlgebra := PolynomialRing => R -> (
   if R#?(symbol degreesRing) then R#(symbol degreesRing)
   else error "no degreesRing for this ring"
   )

isWellDefined FreeAlgebra := Boolean => R -> (
    -- an internal check that R is defined properly.
    isbad := str -> (if debugLevel > 0 then << str; false);
    if # R.generators =!= numgens R then 
        return isbad "# R.generators =!= numgens R";
    if # R.generatorExpressions =!= numgens R then 
        return isbad "# R.generatorExpressions =!= numgens R";
    if # R.generatorSymbols =!= numgens R then 
        return isbad "# R.generatorSymbols =!= numgens R";
    if not all(R.generators, x -> class x === R) then 
        return isbad "generators are not all in the ring";
    if not all(R.generatorExpressions, x -> instance(x,Expression) or instance(x,Symbol)) then
        return isbad "generatorExpressions are not all expressions";
    if not all(R.generatorSymbols, x -> instance(x, Symbol) or instance(x, IndexedVariable)) then
        return isbad "generatorSymbols are not all symbols or indexed variables";
    if not instance(expression R, Expression) then
        return isbad "expression R should be an expression";
    if not instance(describe R, Net) then
        return isbad "'describe R' should be a Net";
    if not instance(net R, Net) then
        return isbad "'net R' should be a Net";
    if not instance(toString R, String) then
        return isbad "'toString R' should be a string";
    if not instance(toExternalString R, String) then
        return isbad "'toExternalString R' should be a string";
    true
    )
-- listForm

NCGB = method()
NCGB(Ideal, ZZ) := (I, maxdeg) -> (
    if not I.cache.?NCGB or I.cache.NCGB#0 < maxdeg then (
        tobecomputed := raw if I.cache.?NCGB then I.cache.NCGB#1 else gens I;
        gbI := map(ring I, rawNCGroebnerBasisTwoSided(tobecomputed, maxdeg));
        I.cache.NCGB = {maxdeg, gbI};
        );
    I.cache.NCGB#1
    )

NCReduction2Sided = method()
NCReduction2Sided(Matrix, Matrix) := (M, I) -> (
    R := ring M;
    if R =!= ring I then error "expected same ring";
    map(R, rawNCReductionTwoSided(raw M, raw I))
    )
NCReduction2Sided(Matrix, Ideal) := (M, I) -> NCReduction2Sided(M, gens I)
NCReduction2Sided(RingElement, Ideal) := (F, I) -> (NCReduction2Sided(matrix{{F}}, gens I))_(0,0)

FreeAlgebra / Ideal := QuotientRing => (R,I) -> (
     if ring I =!= R then error "expected ideal of the same ring";
     if I == 0 then return R;
     A := R;
     while class A === QuotientRing do A = last A.baseRings;
     gensI := generators I;
     maxdegI := first max(degrees source gensI); -- TODO: change once multidegrees are allowed.
     gbI := if I.cache.?NCGB then I.cache.NCGB#1 else NCGB(I, 2*maxdegI);
     S := new QuotientRing from rawQuotientRing(raw R, raw gbI);
     --S#"raw creation log" = Bag { FunctionApplication {rawQuotientRing, (raw R, raw gbI)} };
     S.cache = new CacheTable;
     S.ideal = I;
     S.baseRings = append(R.baseRings,R);
     commonEngineRingInitializations S;
     S.relations = gensI;
     S.isCommutative = false;
     S.generators = apply(generators S, m -> promote(m,S));
     if R.?generatorSymbols then S.generatorSymbols = R.generatorSymbols;
     if R.?generatorExpressions then S.generatorExpressions = (
	  R.generatorExpressions
	  );
     if R.?indexStrings then S.indexStrings = applyValues(R.indexStrings, x -> promote(x,S));
     if R.?indexSymbols then S.indexSymbols = applyValues(R.indexSymbols, x -> promote(x,S));
     expression S := lookup(expression,R);
     S.use = x -> ( -- what is this for??
	  );
     S)

beginDocumentation()

BENCHMARK = method()
BENCHMARK String := (s) -> null

doc ///
Key
  PolynomialAlgebra
Headline
  non-commutative polynomial algebra
Description
  Text
    This code is in active development.
  Example
    R = QQ{a..c}
    R_0
    R_1
    R_2
Caveat
  Not yet functional
SeeAlso
///

TEST ///
-*
  restart
  needsPackage "PolynomialAlgebra"

  restart
  check "PolynomialAlgebra"

*-
  --- generators test
  debug Core -- for generatorSymbols
  R = QQ{a,b,c}; assert(R.generatorSymbols == splice {vars(0,1,2)})
  assert isWellDefined R
    
  R = QQ{a,b,c}; assert(R.generatorSymbols == splice {vars(0,1,2)})
  assert isWellDefined R

  R = QQ{a,b, x_1..x_3, c, y_1..y_4}
  assert(numgens R == 10)
  debugLevel = 1
  isWellDefined R

  R = QQ{{a,b,c},{d,e}}; assert(R.generatorSymbols == splice {vars(0,1,2,3,4)})
  R = QQ{(a,b,c),{d,e}}; assert(R.generatorSymbols == splice {vars(0,1,2,3,4)})
  R = QQ{(a,b,c),(d,e)}; assert(R.generatorSymbols == splice {vars(0,1,2,3,4)})
  R = QQ{b..f}; assert(R.generatorSymbols == splice {vars(1,2,3,4,5)})
  R = QQ{a,b,c}; assert(R.generatorSymbols == splice {vars(0,1,2)})
  R = QQ{x_1..x_100, y_1..y_100}; assert(numgens R == 200)
  debugLevel = 1
  isWellDefined R
///

TEST ///
  -- toExternalString
  -- toString
  -- expression
  -- net
  -- describe
  R = QQ{a,b, x_1..x_3, c, y_1..y_4}
  isWellDefined R
  unstack describe R === {"QQ {a, b, x , x , x , c, y , y , y , y }", 
                            "           1   2   3      1   2   3   4"}
  assert(net R === "R")
  assert(net R == net expression R)
  assert((depth describe R, height describe R, width describe R) == (1,1,40))
  assert(toString R === "R")
  assert(toExternalString R === "QQ {a, b, x_1, x_2, x_3, c, y_1, y_2, y_3, y_4}")
///

TEST ///
  --- equality tests
  R = QQ{a,b,c}
  assert(a != b)
  assert(a == a)
  assert(b*a + a*b + b*a == 2*b*a + a*b)
  assert(R_0 == a)
  f = a^2*b*a^2*b+a^3*b+a^2*b*a+2*a^2*b+a^2+2*a+1
  g = (a*a*b+a+1)*(a*a*b+a+1)
  assert(f == g)
  assert(f - g == 0)
///

TEST ///
  -- printing tests
  R = QQ{a,b,c}
  f = a^2*b*a^2*b+a^3*b+a^2*b*a+2*a^2*b+a^2+2*a+1
  g = (a*a*b+a+1)*(a*a*b+a+1)
  assert(toExternalString(f - g) == "0")
  assert(f == g)
  assert(f-g == 0)
  assert(net f == net expression f)
  assert(toString f === "a^2*b*a^2*b+a^3*b+a^2*b*a+2*a^2*b+a^2+2*a+1")
  assert(toString f === toExternalString f)
-*
  for i from 0 to 10 list (elapsedTime size (h = g^i));
  for i from 0 to 8 list (elapsedTime size (h = g^i))
  g1 = g;
  for i from 0 to 7 do elapsedTime (h = g1*g; g1 = h; print size h) 
  
  g1 = g;  
  for i from 0 to 7 do elapsedTime (h = g*g1; g1 = h; print size h)   
  apply(11, i -> print size elapsedTime(h = g^i));
*-
///

///
i3 :   g = (a*a*b+a+1)*(a*a*b+a+1)

      2   2     3     2        2     2
o3 = a b*a b + a b + a b*a + 2a b + a  + 2a + 1
  
31
     -- 0.000237961 seconds elapsed
127
     -- 0.000494012 seconds elapsed
511
     -- 0.00139882 seconds elapsed
2047
     -- 0.00770198 seconds elapsed
8191
     -- 0.0549404 seconds elapsed
32767
     -- 0.188868 seconds elapsed
131071
     -- 0.583566 seconds elapsed
524287
     -- 2.66607 seconds elapsed
///

BENCHMARK ///
-- this takes currently about 2 GB, so can't be run as a test
  R = QQ{a,b,c,d}
  g = a+b+c+d
  elapsedTime for i from 0 to 11 list (elapsedTime size (h = g^i))
  g3 = g^3
  g5 = g^5
  g8 = g^8;
  assert(g3*g5 == g8)
///

TEST ///
  R = QQ{a,b,c,d}
  g1 = a^2-b*c+c^3
  g2 = a*b*a+c*d*b+3*a*b*c*d
  g3 = a*b+b*c+c*d+d*a-1
  h1 = g1*g2
  h2 = g2*g3
  assert((g1*g2)*g3 == g1*(g2*g3))
  --g1*g2*g3*g2*g1*g3*g1*g3*g2*g1*g2*g1*g2;
  h1 = g1*g2*g3*g2*g1*g3;
  h2 = g1*g3*g2*g1*g2*g1; -- *g2;

  --elapsedTime for i from 0 to 11 list (elapsedTime size (h = g^i))
  g3 = g1^3
  g5 = g1^5
  g8 = g1^8;
  assert(g3*g5 == g8)
///

TEST ///
  needsPackage "PolynomialAlgebra"
  R = QQ{a,b,c,d}
  g1 = a^2-b*c+c^3
  g2 = a*b*a+c*d*b+3*a*b*c*d
  g3 = a*b+b*c+c*d+d*a-1
  h1 = g1*g2*g3*g2*g1;
  h2 = g1*g3*g2*g1*g2;
  size(h1)
  size(h2)
  h3 = elapsedTime(h1*h2); -- memory usage: elapsedTime: 2.59 sec
  assert(size h3 == 164025)
///

BENCHMARK ///
  R = QQ{a,b,c,d}
  g1 = a^2-b*c+c^3
  g2 = a*b*a+c*d*b+3*a*b*c*d
  g3 = a*b+b*c+c*d+d*a-1
  h1 = g1*g2*g3*g2*g1*g2;
  h2 = g1*g3*g2*g1*g2;
  size(h1)
  size(h2)
  h3 = elapsedTime(h1*h2); -- memory usage: 670 MB elapsedTime: 10.2 sec
  assert(size h3 == (size h1) * (size h2))
  assert(size h3 == 492075)
///

BENCHMARK ///
-- This one uses too much memory (about 1.7 GB)
  R = QQ{a,b,c,d}
  g1 = a^2-b*c+c^3
  g2 = a*b*a+c*d*b+3*a*b*c*d
  g3 = a*b+b*c+c*d+d*a-1
  h1 = g1*g2*g3*g2*g1*g2;
  h2 = g1*g3*g2*g1*g2*g1;
  size(h1)
  size(h2)
  h3 = elapsedTime(h1*h2); -- memory usage: 2.4 GB elapsedTime:  90.4 sec
  assert(size h3 == (size h1) * (size h2))
  assert(size h3 == 1476225)
///

BENCHMARK ///
-- this examples uses 2.2 GB
  R = QQ{a,b,c,d,e,f,g}
  G = a+b+c+d+e+f+g
  elapsedTime for i from 0 to 8 list (elapsedTime size (H = G^i))
///

--- question: why is engine code slower for this computation than NCAlgebra?
-- apply(11, i -> time(h = g^i));  -- SIGSEGV?

TEST ///
  --- promote/lift tests
  R = QQ{a,b,c}
  3_R
  assert(promote(3,R) == 3_R)
  assert(promote(23423/324,R) == (23423/324)_R)
  
  debug Core
  A = ZZ/101[s,t]
  B = A{x,y,z}
  promote(s,B)
  f = (s + x + y)^2
  (coeff, monoms) = rawPairs(raw A, raw f)
  peek first monoms

  A = ZZ/101[t]/t^2
  B = A{x,y,z}
  promote(t,B)
  t_B
///

TEST ///
-*
  restart
  needsPackage "PolynomialAlgebra"
*-
  debug Core
  -- basic arithmetic
  A = ZZ/101[t]/t^2
  B = A{x,y,z}
  f = 0_A * x
  raw f 
  
  f = (t*x + t*y)^2
  assert(toString raw f == "0")
  (x + t*y)^2 == x^2 + t*x*y + t*y*x 
  
  f = (t*x + t*y)^2
  f = (t*x + t*y)*(t*x+t*y)
  assert(size f == 0)
///

TEST /// 
  R = QQ{b,c,d}
  f = 3*b^2*c*b + 2*b^4
  assert(size (b+c) == 2)
  terms f == {2*b^4, 3*b^2*c*b}
  assert(# terms f == 2)
  assert(sum terms f == f)
///

TEST /// 
-*
  restart
  needsPackage "PolynomialAlgebra"
*-
  R = QQ{b,c,d}
  assert instance(R, FreeAlgebra)

  f = 3*b^2*c*b + 2*b^4
  assert(leadTerm f == 2*b^4)
  assert(leadCoefficient f == 2)
  assert(degree f == {4})
  assert(someTerms(f,0,2) == f)
  assert(leadMonomial f == b^4) -- FAILS: needs a monoid...
  assert(isHomogeneous f)
  
  g = b*c*b-b
  assert not isHomogeneous g
  
  A = QQ[a]
  B = A{b,c,d}
  f = 3*(a^2-a-1)*b^2*c*b + 2*(a^3-a-1)*b^4
  g = (a+2*b+3*c)^3
  assert(leadCoefficient f == 2*(a^3-a-1))
  assert(leadTerm f == 2*(a^3-a-1)*b^4)
  assert(someTerms(g,2,3) == 12*b*c*b + 18*b*c^2 + 12*c*b^2)
  assert(size g == 15)

  A = frac(QQ[a])
  B = A{b,c,d}
  f = 3/(a^2-a-1)*b^2*c*b + 2/(a^3-a-1)*b^4
  assert(leadCoefficient f == 2/(a^3-a-1))
  assert(leadTerm f == 2/(a^3-a-1)*b^4)
///

TEST /// 
-*
  restart
  needsPackage "PolynomialAlgebra"
*-
  R = QQ{b,c,d, Degrees=>{2,3,4}}
  degree b
  degree c
  degree d
  assert(degree(b*d*c) == {9})
  assert isHomogeneous(b^2-d)
  assert not isHomogeneous(b^2-c)

  R = QQ{b,c,d, Degrees=>{{1,0},{0,1},{3,-4}}}
  degree b
  degree c
  degree d
  assert(degree(b*d*c) == {4,-3})
  assert isHomogeneous(c^4*d-b^3)
  assert(degree(c^4*d-b^3) == {3,0})
  assert not isHomogeneous(b^2-c)
///

TEST ///
  R = QQ{a,b,c,d}
  {b*c}
  e = {{b,c,d,b*c,c*b,b^2,a*c-1}}
  M = matrix for j from 1 to 10 list for i from 1 to 10 list a*b-i*a-j*b
  M_(1,1)
  B = matrix {{b}}
  C = matrix {{c}}
  assert(B*C - matrix {{c*b}} == 0)
  D = matrix {{b,c}}
  assert(D * transpose D - matrix {{b^2 + c^2}} == 0)
  assert(transpose D * D - matrix {{b^2,c*b},{b*c,c^2}} == 0)
///

TEST ///
  R = QQ{b,c,d}
  M = R^2
  B = matrix {{b}}
  C = matrix {{c}}
  assert(B*C - matrix {{c*b}} == 0)
  N = mutableMatrix(R,2,3);
  N = mutableMatrix(R,2,3)
  N = mutableMatrix(R,100,200);
  N_(1,1)
  D = matrix {{b,c}}
  assert(D * transpose D - matrix {{b^2 + c^2}} == 0)
  assert((transpose D * D) - matrix {{b^2,c*b},{b*c,c^2}} == 0)
///

TEST ///
-*
  restart
  needsPackage "PolynomialAlgebra"
*-

  A = QQ[s,t]
  R = QQ{b,c,d}
  F = map(R,A,{b*c,d*c})
  G = map(A,R,{s,t,s*t})
  assert(G b == s)
  assert(G 3 == 3)
  F s
  assert(F (s*t) == d*c*b*c) -- Do we want to allow this? F is not well-defined. kind of a BUG!!
          
  F1 = map(R,R,{c,b,d})
  F1 (b*c*d + b*b*d*c*d*b)

  use R  
  F2 = map(R,R,{c+b,c,d})  
  F2(b+c+d)
  g = 3*b*c + b*c*b -2* b*d*b
  assert(F2 g == 3 * (b+c)*c + (b+c)*c*(b+c) -2* (b+c)*d*(b+c))
  
  B = QQ[b,c,d]
  H1 = map(R,B)
  H2 = map(B,R)
  use R
  H2 (b*c)
  
  R = QQ{b,c,d}
  a1 = (3/4)_R
  lift(a1,QQ) -- ok
  a2 = 3_R
  lift(a2,ZZ) -- ok
  promote(3/4, R)  -- ok
  
  A = ZZ/32003[t]/t^2
  B = A{x,y,z}
  promote(t_A, B) == t_B
  promote(3, B)
  assert(coefficientRing B === A)
  lift(t_B, A)
  
  kk = QQ
  A = kk[a]
  B = A[b]
  C = B{c,d}
  assert(lift(a_C, B) == a_B)
  assert(lift(a_C, A) == a_A)
  assert(try (lift(a_C, kk); false) else true)
///

TEST ///
  RingMap @@ RingMap := (f,g) -> (
      if target g =!= source f then error "Expected composable maps.";
      map(target f, source g, apply(gens source g, x -> f g x))
      )

  R = QQ{b,c,d}
  F1 = map(R,R,{c,b,d})
  F2 = map(R,R,{c+b,c,d})  
  F3 = map(R,R,{b*d-1, c*c-c, b-d})
  G = F1 @@ F2
  G2 = F2 @@ F3
  use R  

  F1 (b*c*d + b*b*d*c*d*b)  
  F2 (b*c*d + b*b*d*c*d*b)  
  F3 (b*c*d + b*b*d*c*d*b)  
///

TEST ///
-*
  restart
  needsPackage "PolynomialAlgebra"
*-
  R = QQ{a,b,c,d}
  M = matrix{{a*b*c-2*a*a*b*a}}
  assert(monomials M == matrix{{a^2*b*a, a*b*c}})
  coefficients M
///

TEST ///
-*
  restart
  needsPackage "PolynomialAlgebra"
*-
  A = QQ[a..d]
  M = matrix{{a,b},{c,d}}
  monomials(M*M*M)
  R = QQ{a,b,c,d}
  M = matrix{{a*b+b*a, a*b+c*d, a*a+b*a}}
  monomials M
  coefficients M

  M = matrix{{a,b},{b,d}}
  M3 = M*M*M
  M6 = M3 | M3
  assert(monomials M6 == monomials M3)
  mons = monomials M6
  (mon,cf) = coefficients M6
  assert(mon*cf == M6)
  assert(mons == monomials mons)

  M = matrix{{a,b},{b,3*d-1}}
  M3 = M*M*M
  M6 = M3 | M3
  assert(monomials M6 == monomials M3)
  mons = monomials M6
  (mon,cf) = coefficients M6
  assert(mon*cf == M6)
  assert(mons == monomials mons)
///

TEST ///
  -- noncommutative reduction test
-*
  restart
  needsPackage "PolynomialAlgebra"
*-
  R = QQ{a..d}
  I = ideal(a*b*a-a*c*b)
  I2 = ideal(a*b*a-a*c*b, d*a*c*b)
  I3 = ideal(a*b - b*a, a*c - c*a, a*d - d*a, b*c - c*b, b*d - d*b, c*d - d*c)
  J = ideal(a*b*a)
  K = ideal(a*c*b)
  L = ideal(a*b*d*c*a*d*b*c*a*b*d*c*c*c*d*b*a)
  debug Core
  map(R, rawNCReductionTwoSided(raw gens I, raw gens I))
  map(R, rawNCReductionTwoSided(raw gens I, raw gens J))
  map(R, rawNCReductionTwoSided(raw gens I, raw gens K))
  map(R, rawNCReductionTwoSided(raw gens I2, raw gens K))

f = a*a-b*c-a
g = NCReduction2Sided(a*f-f*a, ideal(f))
g = -a*b*c+b*c*a
h = a*g + f*b*c
-- TODO: Fix this!
NCReduction2Sided(h, ideal(f,g)) -- never never land
///

TEST ///
  -- noncommutative reduction test
-*
  restart
  needsPackage "PolynomialAlgebra"
*-
  R = QQ{a,b}
  I = ideal(a^2 - b^2)
  gbTrace=3
  debug Core
  NCGB(I, 387)
///

TEST ///
-- test of free algebra quotient rings
-*
-- XXX
  restart
  needsPackage "PolynomialAlgebra"
*-
  debug Core
  R = QQ{a,b}
  I = ideal(a^2 - b^2)
  A = R/I

  NCGB(I, 1000) 
  J = gens ideal NCGB(I, 1000)
  A1 = R/I
  assert(A1 =!= A)
  assert(I.cache.NCGB#0 == 1000)

-- i16 : coefficients(a^3)
-- stdio:16:1:(3): error: expected polynomial ring

-- i17 : lift(a^3, R)
-- stdio:17:1:(3): error: cannot lift given ring element

-- basis(4, A) -- error: can't handle this kind of ring.  
  use R
  f = a^3
  use A
  assert(promote(f, A) == b^2*a)
  assert(a == A_0)
  assert(b == A_1)
  assert(5 == # unique for e in (0,0,0,0)..(1,1,1,1) list product for i in e list A_i)
  assert(6 == # unique for e in (0,0,0,0,0)..(1,1,1,1,1) list product for i in e list A_i)

  R = QQ{a,b,c}
  I = ideal"aba-bab, ac-ca, ab+ba"
  J = gens ideal NCGB(I, 10)  

  -- 'monomials' seems to be working:
  assert(monomials matrix"ab-ba,ab+ba" == matrix"ab,ba")
  assert(numcols monomials J == 131)

  -- coefficients works over free algebras
  coefficients(a^3)
  elapsedTime (monoms, cfs) = coefficients(J, Monomials => monomials J);
  assert(monoms * cfs == J)  
  elapsedTime (monoms, cfs) = coefficients(J);
  assert(monoms * cfs == J)  

  -- monomials, coefficients, over quotients of free algebras.
  A = R/I  

  -- 'monomials' seems to be working:
  assert(monomials matrix"ab-ba,ab+ba" == matrix"ba")
  coefficients(a^3)
  assert(sub(J, A) == 0)
  M = matrix"ab-ba,ac-ba,aca-bab-a3"
  monomials M 
  elapsedTime (monoms, cfs) = coefficients(M, Monomials => monomials M);
  assert(monoms * cfs == M)  
  elapsedTime (monoms, cfs) = coefficients M;
  assert(monoms * cfs == M)  

  sub(M, R) -- NOT CORRECT
  
-- TODO
-*
  . raw A -- display quotient elements, for debugging purposes.
  . coefficients, monomials DONE (might need some more refactoring in c++ code.
  . basis
  . random
  . lift
  .   
*-
///


end--

restart
needsPackage "PolynomialAlgebra"
installPackage "PolynomialAlgebra"
uninstallPackage "PolynomialAlgebra"
viewHelp "PolynomialAlgebra"
check "PolynomialAlgebra"

-- XXX
restart
needsPackage "PolynomialAlgebra"
debug Core
check PolynomialAlgebra

-- play with listForm
-- calls rawPairs, which calls IM2_RingElement_list_form in engine
-- each ring has its own "list_form(coeff ring, ring_elem)"

-- TODO: 1/3/19 MS+FM (DONE means: make sure there are tests for it!!)
-- 1. isEqual DONE
-- 2. mutable matrices DONE
-- 3. promote/lift DONE
-- 4. rawPairs, etc (rawPairs: DONE)
-- 5. leadTerm/Coefficient/Monomial (NOT DONE)
-- 6. terms DONE
-- 7. degrees/weights of variables (NOT DONE)
-- 8. listForm (Not correct for NC case): use rawSparseListFormMonomial.
-- 9. check on ring map evaluation.
-- eventually: 
--  a. want ring of square matrices over a ring.
--  b. Endomorphism ring and/or Ext algebra.
--  c. Skew poly rings
--  d. path algebra?
-- not written:
--   is_homogeneous
--   degree
--   multi_degree
-- order of events:
--  a. fix the little stuff above.
--   a1. then get existing bergman interface to work with this code.
--  b. understand bergman GB/res algorithms/tricks.
--  c. implement GB and res
--  d. add in these other non-commutative rings.
-- Eventually: make a front end type: NCMonoid, or FreeMonoid, ...
--   have PolynomialAlgebra::create use that, instead of create one.
-- Get torsion in a monoid to work.
doc ///
Key
Headline
Usage
Inputs
Outputs
Consequences
Description
  Text
  Example
  Code
  Pre
Caveat
SeeAlso
///

TEST ///
-- test code and assertions here
-- may have as many TEST sections as needed
///

restart
needsPackage "PolynomialAlgebra"
debug Core
A = QQ[x,y]
R = A{b,c,d}
f = 3*x*y*b^2*c*b + 2*b^4
rawP = rawPairs(raw coefficientRing R, raw f)
(rawP#0, rawP#1 / rawSparseListFormMonomial)
-- this code can be used, for example, to get the 'monomial part' of terms.
toList apply(last rawP / rawSparseListFormMonomial, t -> product(apply(t, p -> R_(p#0)^(p#1))))
--- this is how terms is computed.  rawTerm calls IM2_RingElement_term in the engine.
--- Q: Do we change this code to work for PolynomialAlgebra objects as well, or will they
---    get their own function?  (We added a separate function for these types of things in the past).
apply(rawP#0,rawP#1,(c,m) -> new R from rawTerm(raw R, c, m))
