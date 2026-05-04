import { PersonProfileView } from "@/app/_components/profile-pages";
import { people } from "@/app/_data/mock-data";

export default function ProfilePage() {
  return <PersonProfileView person={people[0]} />;
}
