#include "Math/Vector.isph"
#include "Math/Matrix.isph"

static const uniform float Inv_65535 = 1.0f / 65535;

inline uniform FVector4f GetMatrixMultipliedVector(const uniform FVector4f& InVector, const uniform FMatrix44f& InMatrix, const bool bIsNormal)
{
	uniform float FinalVertexReplicated[16];
#if (TARGET_WIDTH == 4)
	for (uniform int I = 0; I < 4; I++)
	{
		foreach(ElementIndex = 0 ... programCount)
		{
			FinalVertexReplicated[4 * I + ElementIndex] = InVector.V[I] * InMatrix.M[4 * I + ElementIndex];
		}
	}
#elif TARGET_WIDTH == 8
	float ReplicatedRow12 = { InVector.V[0], InVector.V[0], InVector.V[0], InVector.V[0], InVector.V[1], InVector.V[1], InVector.V[1], InVector.V[1] };
	float ReplicatedRow34 = { InVector.V[2], InVector.V[2], InVector.V[2], InVector.V[2], InVector.V[3], InVector.V[3], InVector.V[3], InVector.V[3] };
	float Row12 = InMatrix.M[programIndex];
	float Row34 = InMatrix.M[programCount + programIndex];
	FinalVertexReplicated[programIndex] = Row12 * ReplicatedRow12;
	FinalVertexReplicated[programCount + programIndex] = Row34 * ReplicatedRow34;
	FinalVertexReplicated[programIndex] += FinalVertexReplicated[programCount + programIndex];
	uniform FVector4f RetTest;
	foreach(I = 0...3)
	{
		RetTest.V[I] = FinalVertexReplicated[I] + FinalVertexReplicated[4 + I];
	}
	RetTest.V[3] = 0.f;
	return RetTest;

	/*for (uniform int I = 0; I < 2; I++)
	{
		foreach(ElementIndex = 0 ... programCount)
		{
			if (ElementIndex < 4)
			{
				FinalVertexReplicated[8 * I + ElementIndex] = InVector.V[I * 2] * InMatrix.M[8 * I + ElementIndex];
			}
			else
			{
				FinalVertexReplicated[8 * I + ElementIndex] = InVector.V[(I * 2) + 1] * InMatrix.M[8 * I + ElementIndex];
			}
		}
	}*/
#else
	foreach(ElementIndex = 0 ... 16)
	{
		if (ElementIndex < 4)
		{
			FinalVertexReplicated[ElementIndex] = InVector.V[0] * InMatrix.M[ElementIndex];
		}
		else if (ElementIndex >= 4 && ElementIndex < 8)
		{
			FinalVertexReplicated[ElementIndex] = InVector.V[1] * InMatrix.M[ElementIndex];
		}
		else if (ElementIndex > 8 && ElementIndex < 12)
		{
			FinalVertexReplicated[ElementIndex] = InVector.V[2] * InMatrix.M[ElementIndex];
		}
		else
		{
			FinalVertexReplicated[ElementIndex] = InVector.V[3] * InMatrix.M[ElementIndex];
		}
	}
#endif

	/*uniform int NumRows;
	if (bIsNormal)
	{
		NumRows = 3;
	}
	else
	{
		NumRows = 4;
	}*/

	uniform FVector4f Ret;
	foreach(I = 0 ... 4)
	{
		Ret.V[I] = FinalVertexReplicated[I];
	}
	
	/*for (uniform int I = 1; I < NumRows; I++)
	{
		foreach(Column = 0...4)
		{
			Ret.V[Column] = Ret.V[Column] + FinalVertexReplicated[(I * 4) + Column];
		}
	}*/

	return Ret;
}

inline export void CpuSkinMatrixMult(const uniform FVector4f InPositionAndTangents[], const uniform float BoneWeights[],
	const uniform int32 NumBoneWeights, const uniform uint16 BoneMap[], const uniform uint16 BoneIndices[], const uniform FMatrix44f ReferenceToLocal[],
	uniform FVector4f OutPositionAndTangents[])
{
	const uniform FMatrix44f* uniform CurrentBoneMatrix = &ReferenceToLocal[BoneMap[BoneIndices[0]]];
	const uniform FMatrix44f* uniform FinalVertexMatrixPtr;
	uniform FMatrix44f FinalVertexMatrix;
	
	if (BoneWeights[0] < 1.f - FLOAT_SMALL_NUMBER)
	{
		FinalVertexMatrixPtr = &FinalVertexMatrix;
		foreach(MatrixElement = 0 ... 16)
		{
			FinalVertexMatrix.M[MatrixElement] = CurrentBoneMatrix->M[MatrixElement] * BoneWeights[0];
		}

		for (uniform int I = 1; I < NumBoneWeights; I++)
		{
			if (BoneWeights[I] > FLOAT_SMALL_NUMBER)
			{
				CurrentBoneMatrix = &ReferenceToLocal[BoneMap[BoneIndices[I]]];
				foreach(MatrixElement = 0 ... 16)
				{
					FinalVertexMatrix.M[MatrixElement] += CurrentBoneMatrix->M[MatrixElement] * BoneWeights[I];
				}
			}
			else
			{
				break;
			}
		}
	}
	else
	{
		FinalVertexMatrixPtr = CurrentBoneMatrix;
	}

	OutPositionAndTangents[0] = GetMatrixMultipliedVector(InPositionAndTangents[0], *FinalVertexMatrixPtr, false);
	OutPositionAndTangents[1] = GetMatrixMultipliedVector(InPositionAndTangents[1], *FinalVertexMatrixPtr, true);

	uniform FVector4f Tangent2 = InPositionAndTangents[2];
	Tangent2.V[3] = 0.f;
	OutPositionAndTangents[2] = GetMatrixMultipliedVector(Tangent2, *FinalVertexMatrixPtr, true);
	
	uniform FVector4f MultVector = OutPositionAndTangents[1] * OutPositionAndTangents[1];
	uniform float InvSize = rsqrt_fast(MultVector.V[0] + MultVector.V[1] + MultVector.V[2]);
	OutPositionAndTangents[1] = OutPositionAndTangents[1] * InvSize;

	MultVector = OutPositionAndTangents[2] * OutPositionAndTangents[2];
	InvSize = rsqrt_fast(MultVector.V[0] + MultVector.V[1] + MultVector.V[2]);
	OutPositionAndTangents[2] = OutPositionAndTangents[2] * InvSize;
	OutPositionAndTangents[2].V[3] = InPositionAndTangents[2].V[3];
}

inline export void GetAveragedMatrix(const uniform uint16 NumBoneWeights, const uniform uint16 BoneWeights[], const uniform uint16 BoneMap[], const uniform uint16 BoneIndices[],
	const uniform FMatrix44f ReferenceToLocal[],
	uniform float OutBoneWeights[], 
	uniform float OutMatrix[])
{
	foreach(I = 0 ... NumBoneWeights)
	{
		OutBoneWeights[I] = BoneWeights[I] * Inv_65535;
	}

	const uniform FMatrix44f* uniform CurrentBoneMatrix = &ReferenceToLocal[BoneMap[BoneIndices[0]]];
	uniform float CurrentBoneWeight = OutBoneWeights[0];
	foreach(MatrixElement = 0 ... 16)
	{
		OutMatrix[MatrixElement] = CurrentBoneMatrix->M[MatrixElement] * CurrentBoneWeight;
	}

	for (uniform int I = 1; I < NumBoneWeights; I++)
	{
		CurrentBoneWeight = OutBoneWeights[I];
		if (CurrentBoneWeight > FLOAT_SMALL_NUMBER)
		{
			CurrentBoneMatrix = &ReferenceToLocal[BoneMap[BoneIndices[I]]];
			foreach(MatrixElement = 0 ... 16)
			{
				OutMatrix[MatrixElement] += CurrentBoneMatrix->M[MatrixElement] * CurrentBoneWeight;
			}
		}
		else
		{
			break;
		}
	}
}