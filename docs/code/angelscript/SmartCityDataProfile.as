/**
 * SPINDLE step 2 — the shape. Parallel arrays only, never a script-defined
 * struct (Python can't construct those). Values are written by
 * sim/spindle_populate.py straight from the real simulation output; this
 * class only defines what a row looks like.
 */
class USmartCityDataProfile : UDataAsset
{
	UPROPERTY(Category = "Intersections")
	TArray<FName> IntersectionId;
	UPROPERTY(Category = "Intersections")
	TArray<float> IntersectionX;
	UPROPERTY(Category = "Intersections")
	TArray<float> IntersectionZ;

	UPROPERTY(Category = "LightLog")
	TArray<float> LightLogT;
	UPROPERTY(Category = "LightLog")
	TArray<FName> LightLogIntersection;
	UPROPERTY(Category = "LightLog")
	TArray<FName> LightLogNsState;
	UPROPERTY(Category = "LightLog")
	TArray<FName> LightLogEwState;

	UPROPERTY(Category = "ReleaseLog")
	TArray<float> ReleaseLogT;
	UPROPERTY(Category = "ReleaseLog")
	TArray<FName> ReleaseLogIntersection;
	UPROPERTY(Category = "ReleaseLog")
	TArray<FName> ReleaseLogAxis;
	UPROPERTY(Category = "ReleaseLog")
	TArray<FName> ReleaseLogVehicleType;

	UFUNCTION(BlueprintPure)
	int GetIntersectionCount() const
	{
		int N = IntersectionId.Num();
		if (IntersectionX.Num() != N || IntersectionZ.Num() != N)
			return -1;
		return N;
	}

	UFUNCTION(BlueprintPure)
	int GetLightLogCount() const
	{
		int N = LightLogT.Num();
		if (LightLogIntersection.Num() != N || LightLogNsState.Num() != N || LightLogEwState.Num() != N)
			return -1;
		return N;
	}

	UFUNCTION(BlueprintPure)
	int GetReleaseLogCount() const
	{
		int N = ReleaseLogT.Num();
		if (ReleaseLogIntersection.Num() != N || ReleaseLogAxis.Num() != N || ReleaseLogVehicleType.Num() != N)
			return -1;
		return N;
	}
};
