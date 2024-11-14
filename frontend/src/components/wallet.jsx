// import React, { useEffect } from "react";
// import { FaWallet } from "react-icons/fa";
// import { MdDeleteForever } from "react-icons/md";
// import { AppContext } from "../context/AppContext";
// import loadWeb3 from "../helper/connectWallet";

// const chainId = "0x14A34"; // get from server (Relayer network)
// const chainName = "Base Sepolia";
// const rpcURL = "https://sepolia.base.org/";
// const explorerURL = "https://sepolia-explorer.base.org/";

// function WalletButton({}) {
//   // const once = null;
//   const { account, setAccount, loading, setLoading } =
//     React.useContext(AppContext);
//   const [showDelete, setShowDelete] = React.useState(false);
//   useEffect(() => {
//     connect();
//   }, []);
//   const connect = async () => {
//     if (account) {
//       setShowDelete(!showDelete);
//       return;
//     }
//     try {
//       // alert(10)
//       loadWeb3(chainId, chainName, rpcURL, explorerURL).then((acc) =>
//         setAccount(acc[0])
//       ).catch((e) => {});
//     } finally {
//       setLoading(false);
//     }
//   };

//   return (
//     <div className="flex items-center gap-1 cursor-pointer">
//       <div className="p-3 bg-blue-700 text-white rounded-lg" onClick={connect}>
//         {!account ? (
//           <p className="text-sm">Connect</p>
//         ) : (
//           <div className="flex items-center gap-2">
//             <FaWallet size={20} />
//             <p>{account.slice(0, 4) + "***" + account.slice(-4)}</p>
//           </div>
//         )}
//       </div>
//       {showDelete && account && (
//         <div
//           className="bg-red-600 h-full rounded-md items-center flex p-3"
//           onClick={() => {
//             console.log(account);
//             setAccount(null);
//           }}
//         >
//           <MdDeleteForever color="#ff9e9e" size={23} />
//         </div>
//       )}

//       {/* {account && (
//         <div className="border mt-2 rounded-md">
//           <p>Disconnect</p>
//         </div>
//       )} */}
//     </div>
//   );
// }

// export default WalletButton;
