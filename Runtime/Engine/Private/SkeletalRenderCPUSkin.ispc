#include "Math/Matrix.isph"

static uniform float Inv_65535 = 1.f / 65535.f;

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