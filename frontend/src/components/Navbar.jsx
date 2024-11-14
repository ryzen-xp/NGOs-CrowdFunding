// src/components/Navbar.js

import { Link } from "react-router-dom";

const Navbar = () => {
  return (
    <nav>
      <ul>
        <li>
          <Link to="/">Home</Link>
        </li>
        <li>
          <Link to="/create-election">NGO</Link>
        </li>
        <li>
          <Link to="/whitelist">Donor</Link>
        </li>
        <li>
          <Link to="/vote">Admin</Link>
        </li>
        <li>
          <Link to="/results">Connect</Link>
        </li>
      </ul>
    </nav>
  );
};

export default Navbar;
