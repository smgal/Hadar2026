
using UnityEngine;

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Yunjr
{
	/* <StreamingAssets 에 XML 형식으로 세이브 데이터를 만드는 방식>
	 * 테스트를 위한 것이며, 실제로 게임 내에서 동작하는 부분은 아니다.
	 */
	public class SaveDataExample : MonoBehaviour
	{
		public string fileName;

		void Start()
		{
			SaveData data = new SaveData(fileName);

			data["Name"] = "Steve";
			data["Dude"] = "Tom";
			data["Key"] = true;
			data["HealthPotions"] = 10;
			data["Position"] = new Vector3(20, 3, -5);
			data["Rotation"] = new Quaternion(0.1f, 0.1f, 0.1f, 1);

			/*
			 * 이렇게 저장을 하면 ...\Assets\StreamingAssets 에 저장이 되며 만약 디렉토리가 없다면 에러가 난다.
			 * SaveData.uml 과 같은 이름으로 저장이 되며, XML 형식으로 저장이 된다.
			 * 즉, 다른 사람이 수정이 가능한 형태로 바뀐다는 것인데, 전적으로 StreamingAssets의 보안성에 의존하게 된다.
			 */
			data.Save();

			// 방금 저장한 것을 불러 오기
			data = SaveData.Load(Application.streamingAssetsPath + "\\" + fileName + ".uml");

			int potions;

			// 데이터 검증하기
			Debug.Log("Name : " + data.GetValue<string>("Name"));
			Debug.Log("Has health potions : " + data.TryGetValue<int>("HealthPotions", out potions));
			Debug.Log("Health potion count : " + potions);
			Debug.Log("Has buddy : " + data.HasKey("Dude"));
			Debug.Log("Buddy's name : " + data.GetValue<string>("Dude"));
			Debug.Log("Current position : " + data.GetValue<Vector3>("Position"));
			Debug.Log("Has key : " + data.GetValue<bool>("Key"));
			Debug.Log("Rotation : " + data.GetValue<Quaternion>("Rotation"));
		}
	}
}
