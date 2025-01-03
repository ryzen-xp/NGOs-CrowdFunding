import { useState } from "react";
import { Link } from "react-router-dom";
import "./Navbar.css";

function Navbar() {
  const [ngoMenuOpen, setNGoMenuOpen] = useState(false);
  const [donorMenu, setDonorMenu] = useState(false);

  const toggleNgoMenu = () => setNGoMenuOpen(!ngoMenuOpen);
  const toggleDonor = () => setDonorMenu(!donorMenu);

  return (
    <nav className="navbar">
      <ul className="nav-links">
        <li className="nav-link-home">
          <Link to="/">Home</Link>
        </li>

        <li
          className="dropdown"
          onMouseEnter={toggleNgoMenu}
          onMouseLeave={toggleNgoMenu}
        >
          <button className="nav-button">NGO</button>
          {ngoMenuOpen && (
            <ul className="dropdown-menu">
              <li>
                <Link to="/ngo-registration">NGO Registration</Link>
              </li>

              <li>
                <Link to="/ngo-create-req">Create Request</Link>
              </li>
              <li>
                <Link to="/ngo-final-req">Finalied Request</Link>
              </li>
              <li>
                <Link to="/my-ngo">My NGO</Link>
              </li>
            </ul>
          )}
        </li>

        <li
          className="dropdown"
          onMouseEnter={toggleDonor}
          onMouseLeave={toggleDonor}
        >
          <button className="nav-button">Donor</button>
          {donorMenu && (
            <ul className="dropdown-menu">
              <li>
                <Link to="/d-voting">Voting</Link>
              </li>

              <li>
                <Link to="/d-donations">My Donations</Link>
              </li>
            </ul>
          )}
        </li>

        <button className="nav-button">Connect</button>
      </ul>
    </nav>
  );
}

export default Navbar;
// sandep chauhan
