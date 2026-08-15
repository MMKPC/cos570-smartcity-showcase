/**
 * Grid navigator for Matthew's 3x3 road network (measured from his build):
 *   verticals x = {-5410, -3434, -1392}, horizontals y = {15769, 17861, 20191}
 *   9 intersections, one light each. Left-hand traffic (matches his car
 *   placement: each car offset to the LEFT of its travel direction).
 *
 * Cars drive lane-offset along edges, stop at red/yellow before entering an
 * intersection, commit once inside, and choose straight/left/right at every
 * node (straight favored 2:1). Turns are quadratic-bezier lane-to-lane
 * curves through the intersection -- the "complete lane turn".
 *
 * Light states replay the real Python sim log. The 9 grid nodes are grouped
 * onto the 4 logged sim intersections (quadrant mapping); a car approaching
 * north/south uses ns_state, east/west uses ew_state.
 */
struct FNavCar
{
	int AX; int AY;       // node we came from
	int BX; int BY;       // node we're heading to
	int CX; int CY;       // node after B (chosen at entry)
	int Phase;            // 0 = straight leg toward B entry, 1 = curve through B
	float S;              // distance along current piece
	float Lane;           // unsigned lane offset magnitude
	float YawOff;
	float BaseZ;
	int Rng;
	FVector2D Entry; FVector2D Exit; FVector2D Ctrl;
	float PieceLen;
}

class ASmartCityLoopDirector : AActor
{
	default PrimaryActorTick.bStartWithTickEnabled = true;

	UPROPERTY(Category = "Data")
	USmartCityDataProfile Profile;

	UPROPERTY(Category = "Data")
	float PlaybackSpeed = 1.0;

	// 9 lights, index = ix*3+iy (ix west->east, iy south->north)
	UPROPERTY(Category = "Scene")
	TArray<AActor> NodeLights;

	UPROPERTY(Category = "Scene")
	TArray<AActor> Cars;

	UPROPERTY(Category = "Materials")
	UMaterialInterface MatRed;
	UPROPERTY(Category = "Materials")
	UMaterialInterface MatYellow;
	UPROPERTY(Category = "Materials")
	UMaterialInterface MatGreen;

	UPROPERTY(Category = "Track")
	float GridX0 = -5410.0;
	UPROPERTY(Category = "Track")
	float GridX1 = -3434.0;
	UPROPERTY(Category = "Track")
	float GridX2 = -1392.0;
	UPROPERTY(Category = "Track")
	float GridY0 = 15769.0;
	UPROPERTY(Category = "Track")
	float GridY1 = 17861.0;
	UPROPERTY(Category = "Track")
	float GridY2 = 20191.0;

	UPROPERTY(Category = "Tuning")
	float CarSpeed = 320.0;
	UPROPERTY(Category = "Tuning")
	float StopDistance = 450.0;
	// How far before the node center the straight leg ends and the curve begins.
	UPROPERTY(Category = "Tuning")
	float NodeRadius = 170.0;

	// A TextRenderActor in the level; the director writes live sim data into it.
	UPROPERTY(Category = "Debug")
	AActor DebugText;

	float DebugAccum = 0.0;

	float SimTime = 0.0;
	int NextLightIdx = 0;
	bool bReady = false;

	TArray<FName> SimNS;   // 4 sim intersections: current ns_state
	TArray<FName> SimEW;
	TArray<FNavCar> Nav;

	float NodeXOf(int ix) const { return ix == 0 ? GridX0 : (ix == 1 ? GridX1 : GridX2); }
	float NodeYOf(int iy) const { return iy == 0 ? GridY0 : (iy == 1 ? GridY1 : GridY2); }
	FVector2D NodePos(int ix, int iy) const { return FVector2D(NodeXOf(ix), NodeYOf(iy)); }

	// Quadrant-group each grid node onto one of the 4 logged sim intersections.
	// Sim order in the profile: I-NW, I-NE, I-SW, I-SE.
	int SimIdxForNode(int ix, int iy) const
	{
		bool west = (ix == 0) || (ix == 1 && (iy % 2 == 0));
		bool south = (iy == 0) || (iy == 1 && (ix % 2 == 0));
		if (west && !south) return SimSlot(n"I-NW");
		if (!west && !south) return SimSlot(n"I-NE");
		if (west && south) return SimSlot(n"I-SW");
		return SimSlot(n"I-SE");
	}

	int SimSlot(FName Id) const
	{
		for (int i = 0; i < Profile.IntersectionId.Num(); i++)
		{
			if (Profile.IntersectionId[i] == Id)
				return i;
		}
		return 0;
	}

	UFUNCTION(BlueprintOverride)
	void BeginPlay()
	{
		if (Profile == nullptr || NodeLights.Num() != 9)
		{
			Log("SmartCityLoopDirector: need Profile + exactly 9 NodeLights - disabled.");
			return;
		}
		if (Profile.GetLightLogCount() <= 0)
			Log("SmartCityLoopDirector: light log EMPTY - lights stay red.");

		int nSim = Profile.IntersectionId.Num();
		SimNS.SetNum(nSim);
		SimEW.SetNum(nSim);
		for (int i = 0; i < nSim; i++)
		{
			SimNS[i] = n"red";
			SimEW[i] = n"red";
		}
		PaintAll();

		Nav.SetNum(Cars.Num());
		for (int i = 0; i < Cars.Num(); i++)
			InitCar(i);

		SimTime = 0.0;
		NextLightIdx = 0;
		bReady = true;
	}

	// ---------- lights ----------

	void PaintAll()
	{
		for (int ix = 0; ix < 3; ix++)
		{
			for (int iy = 0; iy < 3; iy++)
			{
				int n = ix * 3 + iy;
				AActor L = NodeLights[n];
				if (L == nullptr)
					continue;
				UStaticMeshComponent Comp = UStaticMeshComponent::Get(L);
				if (Comp == nullptr)
					continue;
				FName St = SimNS[SimIdxForNode(ix, iy)];
				if (St == n"green")
					Comp.SetMaterial(0, MatGreen);
				else if (St == n"yellow")
					Comp.SetMaterial(0, MatYellow);
				else
					Comp.SetMaterial(0, MatRed);
			}
		}
	}

	// ---------- car setup ----------

	int NearestIdx3(float v, float a, float b, float c) const
	{
		float da = Math::Abs(v - a); float db = Math::Abs(v - b); float dc = Math::Abs(v - c);
		if (da <= db && da <= dc) return 0;
		if (db <= dc) return 1;
		return 2;
	}

	void InitCar(int i)
	{
		FNavCar C;
		AActor Car = Cars[i];
		if (Car == nullptr)
			return;
		FVector P = Car.GetActorLocation();
		C.BaseZ = P.Z;
		C.Rng = 7919 * (i + 3) + 12345;

		// Which road is the car on? Nearest horizontal vs vertical centerline.
		int ix = NearestIdx3(P.X, GridX0, GridX1, GridX2);
		int iy = NearestIdx3(P.Y, GridY0, GridY1, GridY2);
		float dH = Math::Abs(P.Y - NodeYOf(iy));   // distance to horizontal road line
		float dV = Math::Abs(P.X - NodeXOf(ix));   // distance to vertical road line
		int dirx = 0; int diry = 0;
		if (dH <= dV)
		{
			// On a horizontal road. Left-hand traffic: offset south => heading west.
			C.Lane = dH;
			diry = 0;
			dirx = (P.Y < NodeYOf(iy)) ? -1 : 1;
		}
		else
		{
			// On a vertical road. Offset west => heading north.
			C.Lane = dV;
			dirx = 0;
			diry = (P.X < NodeXOf(ix)) ? 1 : -1;
		}
		if (C.Lane < 20.0)
			C.Lane = 55.0;

		// B = next node along travel; A = node behind.
		int bx = ix; int by = iy;
		if (dirx > 0 && NodeXOf(ix) < P.X + 1.0) bx = Math::Min(ix + 1, 2);
		if (dirx < 0 && NodeXOf(ix) > P.X - 1.0) bx = Math::Max(ix - 1, 0);
		if (diry > 0 && NodeYOf(iy) < P.Y + 1.0) by = Math::Min(iy + 1, 2);
		if (diry < 0 && NodeYOf(iy) > P.Y - 1.0) by = Math::Max(iy - 1, 0);
		C.BX = bx; C.BY = by;
		C.AX = bx - dirx; C.AY = by - diry;
		C.AX = Math::Clamp(C.AX, 0, 2);
		C.AY = Math::Clamp(C.AY, 0, 2);
		if (C.AX == C.BX && C.AY == C.BY)
		{
			C.AX = Math::Clamp(bx - dirx, 0, 2);
			C.AY = Math::Clamp(by - diry, 0, 2);
		}

		PickNext(C);
		BuildStraight(C);
		// Start partway along the leg, at the car's current position projection.
		FVector2D d = C.Exit - C.Entry;
		float len2 = d.SizeSquared();
		float t = 0.0;
		if (len2 > 1.0)
			t = Math::Clamp(((P.X - C.Entry.X) * d.X + (P.Y - C.Entry.Y) * d.Y) / len2, 0.0, 0.98);
		C.S = t * C.PieceLen;

		// Preserve his placed facing (cardinal-snapped offset from travel yaw).
		float TravelYaw = Math::Atan2(float(diry), float(dirx)) * 57.295779513;
		float Delta = Car.GetActorRotation().Yaw - TravelYaw;
		while (Delta > 180.0) Delta -= 360.0;
		while (Delta < -180.0) Delta += 360.0;
		int Quarter = int((Delta + (Delta >= 0.0 ? 45.0 : -45.0)) / 90.0);
		C.YawOff = float(Quarter) * 90.0;

		Nav[i] = C;
	}

	// ---------- routing ----------

	int NextRand(FNavCar& C)
	{
		C.Rng = (C.Rng * 1103515245 + 12345) & 0x7FFFFFFF;
		return C.Rng;
	}

	void PickNext(FNavCar& C)
	{
		int dirx = C.BX - C.AX;
		int diry = C.BY - C.AY;
		// Candidate continuations from B, excluding the U-turn back to A.
		TArray<int> cxs; TArray<int> cys; TArray<int> weight;
		int nbx = 0; int nby = 0;
		for (int k = 0; k < 4; k++)
		{
			int ddx = (k == 0 ? 1 : (k == 1 ? -1 : 0));
			int ddy = (k == 2 ? 1 : (k == 3 ? -1 : 0));
			nbx = C.BX + ddx; nby = C.BY + ddy;
			if (nbx < 0 || nbx > 2 || nby < 0 || nby > 2)
				continue;
			if (nbx == C.AX && nby == C.AY)
				continue;
			cxs.Add(nbx); cys.Add(nby);
			weight.Add((ddx == dirx && ddy == diry) ? 2 : 1);
		}
		if (cxs.Num() == 0)
		{
			// Dead end (shouldn't happen on this grid): U-turn.
			C.CX = C.AX; C.CY = C.AY;
			return;
		}
		int total = 0;
		for (int k = 0; k < weight.Num(); k++)
			total += weight[k];
		int roll = NextRand(C) % total;
		for (int k = 0; k < cxs.Num(); k++)
		{
			roll -= weight[k];
			if (roll < 0)
			{
				C.CX = cxs[k]; C.CY = cys[k];
				return;
			}
		}
		C.CX = cxs[0]; C.CY = cys[0];
	}

	// ---------- geometry ----------

	FVector2D LeftOf(float dx, float dy) const
	{
		// Left-hand side of travel direction (left-hand traffic).
		return FVector2D(dy, -dx) * -1.0;   // rotate dir +90 deg = left
	}

	void BuildStraight(FNavCar& C)
	{
		FVector2D A = NodePos(C.AX, C.AY);
		FVector2D B = NodePos(C.BX, C.BY);
		FVector2D d = B - A;
		float L = d.Size();
		if (L < 1.0)
			L = 1.0;
		FVector2D dir = d / L;
		FVector2D lane = LeftOf(dir.X, dir.Y) * C.Lane;
		C.Entry = A + dir * NodeRadius + lane;
		C.Exit = B - dir * NodeRadius + lane;
		C.Ctrl = (C.Entry + C.Exit) * 0.5;
		C.PieceLen = (C.Exit - C.Entry).Size();
		C.Phase = 0;
		C.S = 0.0;
	}

	void BuildCurve(FNavCar& C)
	{
		// Curve through node B: from end of AB leg to start of BC leg.
		FVector2D B = NodePos(C.BX, C.BY);
		FVector2D dIn = B - NodePos(C.AX, C.AY);
		float lIn = dIn.Size(); if (lIn < 1.0) lIn = 1.0;
		FVector2D dirIn = dIn / lIn;
		FVector2D dOut = NodePos(C.CX, C.CY) - B;
		float lOut = dOut.Size(); if (lOut < 1.0) lOut = 1.0;
		FVector2D dirOut = dOut / lOut;

		FVector2D laneIn = LeftOf(dirIn.X, dirIn.Y) * C.Lane;
		FVector2D laneOut = LeftOf(dirOut.X, dirOut.Y) * C.Lane;
		C.Entry = B - dirIn * NodeRadius + laneIn;
		C.Exit = B + dirOut * NodeRadius + laneOut;
		bool straight = (Math::Abs(dirIn.X - dirOut.X) < 0.01 && Math::Abs(dirIn.Y - dirOut.Y) < 0.01);
		if (straight)
			C.Ctrl = (C.Entry + C.Exit) * 0.5;
		else if (Math::Abs(dirIn.X) > 0.5)
			C.Ctrl = FVector2D(C.Exit.X, C.Entry.Y);   // came in horizontal
		else
			C.Ctrl = FVector2D(C.Entry.X, C.Exit.Y);   // came in vertical
		float chord = (C.Exit - C.Entry).Size();
		float viaCtrl = (C.Ctrl - C.Entry).Size() + (C.Exit - C.Ctrl).Size();
		C.PieceLen = (chord + viaCtrl) * 0.5;
		if (C.PieceLen < 1.0)
			C.PieceLen = 1.0;
		C.Phase = 1;
		C.S = 0.0;
	}

	// ---------- per-frame ----------

	FName StateForApproach(const FNavCar& C) const
	{
		// One bulb per intersection = all-way signal: the displayed color
		// (the mapped sim intersection's NS state) governs every approach.
		// Axis-split control exists in the logged data (ew_state) but showing
		// one color while enforcing another read as cars running the red.
		return SimNS[SimIdxForNode(C.BX, C.BY)];
	}

	void TickCar(int i, float Dt)
	{
		AActor Car = Cars[i];
		if (Car == nullptr || Nav[i].PieceLen <= 0.0)
			return;
		FNavCar C = Nav[i];

		float move = CarSpeed * Dt;
		if (C.Phase == 0)
		{
			float remaining = C.PieceLen - C.S;
			FName st = StateForApproach(C);
			if (st != n"green" && remaining < StopDistance)
				move = Math::Min(move, Math::Max(remaining - 30.0, 0.0));
		}

		C.S += move;
		if (C.S >= C.PieceLen)
		{
			if (C.Phase == 0)
			{
				BuildCurve(C);
			}
			else
			{
				// Curve done: advance nodes, choose the next one, new straight leg.
				C.AX = C.BX; C.AY = C.BY;
				C.BX = C.CX; C.BY = C.CY;
				PickNext(C);
				BuildStraight(C);
			}
		}

		float t = Math::Clamp(C.S / C.PieceLen, 0.0, 1.0);
		FVector2D Pos;
		FVector2D Tan;
		if (C.Phase == 0)
		{
			Pos = C.Entry + (C.Exit - C.Entry) * t;
			Tan = C.Exit - C.Entry;
		}
		else
		{
			float u = 1.0 - t;
			Pos = C.Entry * (u * u) + C.Ctrl * (2.0 * u * t) + C.Exit * (t * t);
			Tan = (C.Ctrl - C.Entry) * (2.0 * u) + (C.Exit - C.Ctrl) * (2.0 * t);
		}
		float Yaw = Math::Atan2(Tan.Y, Tan.X) * 57.295779513;
		Car.SetActorLocation(FVector(Pos.X, Pos.Y, C.BaseZ));
		Car.SetActorRotation(FRotator(0.0, Yaw + C.YawOff, 0.0));

		Nav[i] = C;
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaSeconds)
	{
		if (!bReady)
			return;

		SimTime += DeltaSeconds * PlaybackSpeed;

		int LightCount = Profile.LightLogT.Num();
		bool changed = false;
		while (NextLightIdx < LightCount && Profile.LightLogT[NextLightIdx] <= SimTime)
		{
			int slot = SimSlot(Profile.LightLogIntersection[NextLightIdx]);
			SimNS[slot] = Profile.LightLogNsState[NextLightIdx];
			SimEW[slot] = Profile.LightLogEwState[NextLightIdx];
			changed = true;
			NextLightIdx++;
		}
		if (changed)
			PaintAll();

		for (int c = 0; c < Cars.Num(); c++)
			TickCar(c, DeltaSeconds);

		DebugAccum += DeltaSeconds;
		if (DebugAccum >= 0.25)
		{
			DebugAccum = 0.0;
			UpdateDebugText();
		}
	}

	FString StLetter(FName St) const
	{
		if (St == n"green") return "G";
		if (St == n"yellow") return "Y";
		return "R";
	}

	void UpdateDebugText()
	{
		if (DebugText == nullptr)
			return;
		UTextRenderComponent Txt = UTextRenderComponent::Get(DebugText);
		if (Txt == nullptr)
			return;

		FString s = f"SIM t = {int(SimTime)} s   events {NextLightIdx}/{Profile.LightLogT.Num()}\n";
		for (int i = 0; i < Profile.IntersectionId.Num(); i++)
		{
			FString ns = StLetter(SimNS[i]);
			FString ew = StLetter(SimEW[i]);
			s += f"{Profile.IntersectionId[i]}  NS:{ns}  EW:{ew}\n";
		}
		int stopped = 0;
		for (int c = 0; c < Cars.Num(); c++)
		{
			if (Nav[c].Phase == 0)
			{
				float remaining = Nav[c].PieceLen - Nav[c].S;
				FName st = StateForApproach(Nav[c]);
				if (st != n"green" && remaining < StopDistance)
					stopped++;
			}
		}
		s += f"cars {Cars.Num()}   waiting {stopped}";
		Txt.SetText(FText::FromString(s));
	}
};
