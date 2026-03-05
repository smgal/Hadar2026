
#if (SMGAL)

using UnityEngine;
using System.Collections;
using GooglePlayGames;
using GooglePlayGames.BasicApi;
using GooglePlayGames.BasicApi.SavedGame;

public static class GoogleplayGameServiceManager
{
	static readonly string SAVE_FILE_NAME = "LoreEp2Cloud";

	// 게임서비스 플러그인 초기화시에 EnableSavedGames()를 넣어서 저장된 게임 사용할 수 있게 합니다.
	// 주의 하실점은 구글플레이 개발자 콘솔의 게임서비스에서 해당게임의 세부정보에서 저장된 게임 사용을 
	// 하도록 설정하셔야 합니다.
	public static void Init()
	{
		PlayGamesClientConfiguration config = new PlayGamesClientConfiguration.Builder().EnableSavedGames().Build();
		PlayGamesPlatform.InitializeInstance(config);
		//
		PlayGamesPlatform.DebugLogEnabled = false;
		//Activate the Google Play gaems platform
		PlayGamesPlatform.Activate();
	}

	//인증여부 확인
	public static bool CheckLogin()
	{
		return Social.localUser.authenticated;
	}

	public static void Login()
	{
		Social.localUser.Authenticate(success =>
		{
			if (success)
			{
				Debug.Log("Authentication successful");
				string userInfo = "Username: " + Social.localUser.userName +
					"\nUser ID: " + Social.localUser.id +
					"\nIsUnderage: " + Social.localUser.underage;
				Debug.Log(userInfo);
				Social.ShowAchievementsUI();
			}
			else
				Debug.Log("Authentication failed");
		});
	}

	//--------------------------------------------------------------------
	//게임 저장은 다음과 같이 합니다.
	public static void SaveToCloud()
	{
		if (!CheckLogin()) //로그인되지 않았으면
		{
			//로그인루틴을 진행하던지 합니다.
			return;
		}
		//파일이름에 적당히 사용하실 파일이름을 지정해줍니다.
		OpenSavedGame(SAVE_FILE_NAME, true);
	}

	static void OpenSavedGame(string filename, bool bSave)
	{
		ISavedGameClient savedGameClient = PlayGamesPlatform.Instance.SavedGame;
		if (bSave)
			savedGameClient.OpenWithAutomaticConflictResolution(filename, DataSource.ReadCacheOrNetwork, ConflictResolutionStrategy.UseLongestPlaytime, OnSavedGameOpenedToSave); //저장루틴진행
		else
			savedGameClient.OpenWithAutomaticConflictResolution(filename, DataSource.ReadCacheOrNetwork, ConflictResolutionStrategy.UseLongestPlaytime, OnSavedGameOpenedToRead); //로딩루틴 진행
	}

	//savedGameClient.OpenWithAutomaticConflictResolution 호출시 아래 함수를 콜백으로 지정했습니다. 준비된경우 자동으로 호출될겁니다.
	static void OnSavedGameOpenedToSave(SavedGameRequestStatus status, ISavedGameMetadata game)
	{
		if (status == SavedGameRequestStatus.Success)
		{
			// handle reading or writing of saved game.
			//파일이 준비되었습니다. 실제 게임 저장을 수행합니다.
			//저장할데이터바이트배열에 저장하실 데이터의 바이트 배열을 지정합니다.
			byte[] savedData = new byte[10];
			SaveGame(game, savedData, System.DateTime.Now.TimeOfDay);
		}
		else
		{
			//파일열기에 실패 했습니다. 오류메시지를 출력하든지 합니다.
		}
	}

	static void SaveGame(ISavedGameMetadata game, byte[] savedData, System.TimeSpan totalPlaytime)
	{
		ISavedGameClient savedGameClient = PlayGamesPlatform.Instance.SavedGame;
		SavedGameMetadataUpdate.Builder builder = new SavedGameMetadataUpdate.Builder();
		builder = builder
			.WithUpdatedPlayedTime(totalPlaytime)
			.WithUpdatedDescription("Saved game at " + System.DateTime.Now);
		/*
        if (savedImage != null)
        {
            // This assumes that savedImage is an instance of Texture2D
            // and that you have already called a function equivalent to
            // getScreenshot() to set savedImage
            // NOTE: see sample definition of getScreenshot() method below
            byte[] pngData = savedImage.EncodeToPNG();
            builder = builder.WithUpdatedPngCoverImage(pngData);
        }*/
		SavedGameMetadataUpdate updatedMetadata = builder.Build();
		savedGameClient.CommitUpdate(game, updatedMetadata, savedData, OnSavedGameWritten);
	}

	static void OnSavedGameWritten(SavedGameRequestStatus status, ISavedGameMetadata game)
	{

		if (status == SavedGameRequestStatus.Success)
		{
			//데이터 저장이 완료되었습니다.
		}
		else
		{
			//데이터 저장에 실패 했습니다.
		}
	}

	//----------------------------------------------------------------------------------------------------------------
	//클라우드로 부터 파일읽기
	public static void LoadFromCloud()
	{
		if (!CheckLogin())
		{
			//로그인되지 않았으니 로그인 루틴을 진행하던지 합니다.
			return;
		}
		//내가 사용할 파일이름을 지정해줍니다. 그냥 컴퓨터상의 파일과 똑같다 생각하시면됩니다.
		OpenSavedGame(SAVE_FILE_NAME, false);
	}

	static void OnSavedGameOpenedToRead(SavedGameRequestStatus status, ISavedGameMetadata game)
	{
		if (status == SavedGameRequestStatus.Success)
		{
			// handle reading or writing of saved game.
			LoadGameData(game);
		}
		else
		{
			//파일열기에 실패 한경우, 오류메시지를 출력하던지 합니다.
		}
	}

	//데이터 읽기를 시도합니다.
	static void LoadGameData(ISavedGameMetadata game)
	{
		ISavedGameClient savedGameClient = PlayGamesPlatform.Instance.SavedGame;
		savedGameClient.ReadBinaryData(game, OnSavedGameDataRead);
	}

	static void OnSavedGameDataRead(SavedGameRequestStatus status, byte[] data)
	{
		if (status == SavedGameRequestStatus.Success)
		{
			// handle processing the byte array data
			// 데이터 읽기에 성공했습니다.
			// data 배열을 복구해서 적절하게 사용하시면됩니다.
		}
		else
		{
			// 읽기에 실패 했습니다. 오류메시지를 출력하던지 합니다.
		}
	}
}

#endif
